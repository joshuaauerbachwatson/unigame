/**
 * Copyright (c) 2021-present, Joshua Auerbach
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import AuerbachLook

// Manage access credentials (using an auth provider such as Auth0).

fileprivate let CredentialsFile = "credentials"

// The stored credentials
public struct Credentials: Codable, Sendable {
    public let accessToken: String
    public let expires: Date
    var valid: Bool {
        expires > Date.now
    }
    public init(accessToken: String, expires: Date) {
        self.accessToken = accessToken
        self.expires = expires
    }
}

// A provider for the token when an unexpired one is not found stored locally.
// The token must be valid for audience https://unigame.com in order to validate at the server.
public protocol TokenProvider: Sendable {
    func login() async -> Result<Credentials, Error>
}

// Provides load and store operations for Credentials and a 'login' cover function for the token provider
// that stores the result.  The load operation guards against the use of expired tokens.
class CredentialStore {
    // Load function.  Returns accessToken, manages expiration and serialization errors internally
    class func load() -> Credentials? {
        let storageFile = getDocDirectory().appendingPathComponent(CredentialsFile)
        do {
            let archived = try Data(contentsOf: storageFile)
            Logger.log("Credentials loaded from disk")
            let decoder = JSONDecoder()
            return try decoder.decode(Credentials.self, from: archived)
        } catch {
            Logger.log("Credentials could not be loaded or could not be decoded")
            try? FileManager.default.removeItem(at: storageFile)
        }
        return nil
    }
    
    // Store a new set of credentials
    class func store(_ creds: Credentials) -> Bool {
        let encoder = JSONEncoder()
        guard let encoded = try? encoder.encode(creds) else { return false }
        let storageFile = getDocDirectory().appendingPathComponent(CredentialsFile).path
        FileManager.default.createFile(atPath: storageFile, contents: encoded, attributes: nil)
        return true
    }
}
