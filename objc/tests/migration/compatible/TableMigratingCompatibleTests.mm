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

#import "MigrationCompatibleTestCase.h"

@interface TableMigratingCompatibleTests : MigrationCompatibleTestCase

@end

@implementation TableMigratingCompatibleTests

- (void)setUp
{
    self.isCrossDatabaseMigration = NO;
    [super setUp];

    BOOL done;
    TestCaseAssertTrue([self.database stepMigration:true done:done]);
    TestCaseAssertFalse(done);
}

- (void)test_insert_auto_increment
{
    [super doTestInsertAutoIncrement];
}

- (void)test_insert_or_replace
{
    [super doTestInsertOrReplace];
}

- (void)test_insert_failed_with_conflict
{
    [super doTestInsertFailedWithConflict];
}

- (void)test_limited_delete
{
    [super doTestLimitedDelete];
}

- (void)test_limited_update
{
    [super doTestLimitedUpdate];
}

- (void)test_select
{
    [super doTestSelect];
}

- (void)test_drop_table
{
    [super doTestDropTable];
}

- (void)test_subquery_within_delete
{
    [super doTestSubqueryWithinDelete];
}

- (void)test_subquery_within_update
{
    [super doTestSubqueryWithinUpdate];
}

@end