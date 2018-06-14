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

#ifndef CipherConfig_hpp
#define CipherConfig_hpp

#include <WCDB/Config.hpp>

#pragma GCC visibility push(hidden)

namespace WCDB {

class CipherConfig : public Config {
public:
    CipherConfig(const Data &cipher, int pageSize);
    bool invoke(Handle *handle) override;

    static constexpr const char *name = "WCDBCipher";

protected:
    const Data &getKey() const;

    Data m_key;
    int m_pageSize;
};

} //namespace WCDB

#pragma GCC visibility pop

#endif /* CipherConfig_hpp */