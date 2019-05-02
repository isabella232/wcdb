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

#ifndef __WCDB_MIGRATION_QUEUE_HPP
#define __WCDB_MIGRATION_QUEUE_HPP

#include <WCDB/AsyncQueue.hpp>
#include <WCDB/TimedQueue.hpp>

namespace WCDB {

class MigrationQueueEvent {
public:
    virtual ~MigrationQueueEvent() = 0;

protected:
    virtual std::pair<bool, bool> databaseShouldMigrate(const String& path) = 0;
    friend class MigrationQueue;
};

class MigrationQueue final : public AsyncQueue {
public:
    MigrationQueue(const String& name, MigrationQueueEvent* event);

    void put(const String& path);
    void remove(const String& path);

protected:
    void loop() override final;

    bool onTimed(const String& path, const int& numberOfFailures);
    TimedQueue<String, int> m_timedQueue;
    MigrationQueueEvent* m_event;
};

} // namespace WCDB

#endif /* __WCDB_MIGRATION_QUEUE_HPP */