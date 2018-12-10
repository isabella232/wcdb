/*
 * Tencent is pleased to support the open source community by making
 * WCDB available.
 *
 * Copyright (C) 2017 THL A29 Limited, a Tencent company.
 * All rights reserved.
 *
 * Licensed under the BSD 3-Clause License (the "License"); you may not use
 * this file except in compliance with the License. You may obtain a copy of
 * the License at
 *
 *       https://opensource.org/licenses/BSD-3-Clause
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "AllTypesObject+WCTTableCoding.h"
#import "AllTypesObject.h"
#import "CRUDTestCase.h"
#import "TestCaseObject+WCTTableCoding.h"
#import "TestCaseObject.h"

@interface RetrieveRobustyTests : CRUDTestCase

@property (nonatomic, readonly) double expectedAttackRadio;
@property (nonatomic, readonly) NSString* tablePrefix;
@property (nonatomic, readonly) NSInteger expectedDatabaseSize;
@property (nonatomic, readonly) double deviationForTolerance;

@property (nonatomic, readonly) int step;
@property (nonatomic, readonly) int shuffle;

@end

@implementation RetrieveRobustyTests

- (void)setUp
{
    [super setUp];

    _expectedAttackRadio = 0.01;
    _tablePrefix = @"t_";
    _expectedDatabaseSize = 10 * 1024 * 1024;
    _deviationForTolerance = 0.02;

    _shuffle = 3;
    _step = 3;
    TestCaseAssertTrue(_step >= _shuffle);

    [self.database removeConfigForName:WCTConfigNameCheckpoint];
}

- (int)getRealStep
{
    return self.step + ([NSNumber randomUInt32] % self.shuffle) * [NSNumber randomBool] ? 1 : -1;
}

- (BOOL)shouldAttack
{
    return [NSNumber random_0_1] < self.expectedAttackRadio;
}

- (BOOL)isToleranceForRetrieveScore:(double)retrieveScore
                    andObjectsScore:(double)objectsScore
{
    return retrieveScore < objectsScore * (1 + self.deviationForTolerance) && retrieveScore > objectsScore * (1 - self.deviationForTolerance);
}

- (double)getObjectsScoreFromRetrievedTableObjects:(NSDictionary<NSString*, NSArray<TestCaseObject*>*>*)retrievedTableObjects
                           andExpectedTableObjects:(NSDictionary<NSString*, NSArray<TestCaseObject*>*>*)expectedTableObjects
{
    int totalCount = 0;
    int retrievedCount = 0;
    int matchedCount = 0;
    for (NSString* expectedTableName in expectedTableObjects.allKeys) {
        NSArray<TestCaseObject*>* expectedObjects = [expectedTableObjects objectForKey:expectedTableName];
        NSSet<TestCaseObject*>* expectedObjectsSet = [NSSet setWithArray:expectedObjects];
        TestCaseAssertTrue(expectedObjectsSet.count == expectedObjects.count);
        totalCount += expectedObjectsSet.count;

        NSArray<TestCaseObject*>* retrievedObjects = [retrievedTableObjects objectForKey:expectedTableName];
        retrievedCount += retrievedObjects.count;
        if (retrievedObjects.count > 0) {
            for (TestCaseObject* retrievedObject in retrievedObjects) {
                if ([expectedObjectsSet containsObject:retrievedObject]) {
                    ++matchedCount;
                }
            }
        }
    }
    return (double) matchedCount / totalCount;
}

- (BOOL)fillDatabaseUntilMeetExpectedSize
{
    NSString* currentTable = nil;
    BOOL checkpointed = NO; // leave wal exists
    [self.console disableSQLTrace];
    while (checkpointed || [self.database getFilesSize] < self.expectedDatabaseSize) {
        if (currentTable == nil || [NSNumber randomUInt8] % 10 == 0) {
            currentTable = [NSString stringWithFormat:@"%@%@", self.tablePrefix, [NSString randomString]];
            if (![self.database createTableAndIndexes:currentTable withClass:TestCaseObject.class]) {
                TESTCASE_FAILED
                return NO;
            }
        }

        NSMutableArray<TestCaseObject*>* objects = [NSMutableArray<TestCaseObject*> array];
        int count = 0;
        do {
            count = [NSNumber randomUInt8];
        } while (count == 0);
        for (int i = 0; i < count; ++i) {
            TestCaseObject* object = [[TestCaseObject alloc] init];
            object.isAutoIncrement = YES;
            object.content = [NSString randomString];
            [objects addObject:object];
        }
        if (![self.database insertObjects:objects intoTable:currentTable]) {
            TESTCASE_FAILED
            return NO;
        }
        if ([NSNumber randomUInt8] % 10 == 0) {
            if (![self.database execute:WCDB::StatementPragma().pragma(WCDB::Pragma::walCheckpoint()).to("TRUNCATE")]) {
                TESTCASE_FAILED
                return NO;
            }
            checkpointed = YES;
        } else {
            checkpointed = NO;
        }
    }
    [self.console enableSQLTrace];
    if (![self.fileManager fileExistsAtPath:self.walPath]) {
        TESTCASE_FAILED
        return NO;
    }
    return YES;
}

- (NSDictionary<NSString*, NSArray<TestCaseObject*>*>*)getTableObjects
{
    NSMutableDictionary<NSString*, NSArray<TestCaseObject*>*>* tableObjects = [NSMutableDictionary<NSString*, NSArray<TestCaseObject*>*> dictionary];
    {
        // get all objects
        NSString* likeExpressions = [NSString stringWithFormat:@"%@%%", self.tablePrefix];
        NSArray* tableNames = [self.database getColumnFromStatement:WCDB::StatementSelect().select(WCTMaster.name).from(WCTMaster.tableName).where(WCTMaster.name.like(likeExpressions))];
        if (tableNames.count == 0) {
            TESTCASE_FAILED
            return nil;
        }
        for (NSString* tableName in tableNames) {
            NSArray<TestCaseObject*>* objects = [self.database getObjectsOfClass:TestCaseObject.class fromTable:tableName];
            if (objects != nil) {
                [tableObjects setObject:objects forKey:tableName];
            }
        }
    }
    return tableObjects;
}

- (double)pageBasedAttackAsExpectedRadio
{
    __block double attackedRatio = 0;

    // make database corrupted
    [self.database close:^{
        int totalPageCount = 0;
        int totalAttackedCount = 0;
        {
            // database
            NSFileHandle* fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:self.path];
            if (!fileHandle) {
                TESTCASE_FAILED
                return;
            }
            NSInteger fileSize = [fileHandle seekToEndOfFile];
            if (fileSize == 0) {
                TESTCASE_FAILED
                return;
            }
            int pageCount = (int) (fileSize / self.pageSize);
            totalPageCount += pageCount;
            TestCaseAssertTrue(fileSize % self.pageSize == 0) for (int i = 0; i < pageCount; ++i)
            {
                if ([self shouldAttack]) {
                    [fileHandle seekToFileOffset:i * self.pageSize];
                    [fileHandle writeData:[NSData randomDataWithLength:self.pageSize]];
                    ++totalAttackedCount;
                }
            }
            [fileHandle closeFile];
        }

        {
            // wal
            NSFileHandle* fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:self.walPath];
            if (!fileHandle) {
                TESTCASE_FAILED
                return;
            }
            NSInteger fileSize = [fileHandle seekToEndOfFile];
            if (fileSize == 0) {
                TESTCASE_FAILED
                return;
            }
            int frameCount = (int) ((fileSize - self.walHeaderSize) / self.walFrameSize);
            totalPageCount += frameCount;
            TestCaseAssertTrue((fileSize - self.walHeaderSize) % self.walFrameSize == 0) for (int i = 0; i < frameCount; ++i)
            {
                if ([self shouldAttack]) {
                    [fileHandle seekToFileOffset:i * self.walFrameSize + self.walHeaderSize];
                    [fileHandle writeData:[NSData randomDataWithLength:self.walFrameSize]];
                    ++totalAttackedCount;
                }
            }
            [fileHandle closeFile];
        }
        attackedRatio = (float) totalAttackedCount / totalPageCount;
    }];
    return attackedRatio;
}

- (void)test_feature_page_based_robusty
{
    TestCaseAssertTrue([self fillDatabaseUntilMeetExpectedSize]);

    NSDictionary<NSString*, NSArray<TestCaseObject*>*>* expectedTableObjects = [self getTableObjects];
    TestCaseAssertTrue(expectedTableObjects != nil);

    TestCaseAssertTrue([self.database backup]);

    double attackedRadio = [self pageBasedAttackAsExpectedRadio];
    TestCaseAssertTrue(attackedRadio > 0);

    double retrievedScore = [self.database retrieve:nullptr];

    NSDictionary<NSString*, NSArray<TestCaseObject*>*>* retrievedTableObjects = [self getTableObjects];
    TestCaseAssertTrue(retrievedTableObjects != nil);

    double objectsScore = [self getObjectsScoreFromRetrievedTableObjects:retrievedTableObjects andExpectedTableObjects:expectedTableObjects];

    TestLog(@"Radio: attacked: %.8f, expected %.8f", attackedRadio, self.expectedAttackRadio);
    TestLog(@"Score: retrieve: %.8f, objects: %.8f", retrievedScore, objectsScore);

    TestCaseAssertTrue([self isToleranceForRetrieveScore:retrievedScore andObjectsScore:objectsScore]);
}

@end