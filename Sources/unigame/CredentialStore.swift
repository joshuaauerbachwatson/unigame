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
public struct Credentials: Codable {
    public let accessToken: String
    public let expires: Date
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

// Covers the local storage of access token and expiration.  Uses TokenProvider protocol for actual login
class CredentialStore {
    // Access variable for credentials.  If there are no credentials in storage, returns nil
    var credentials: Credentials? {
        let storageFile = getDocDirectory().appendingPathComponent(CredentialsFile)
        do {
            let archived = try Data(contentsOf: storageFile)
            Logger.log("Credentials loaded from disk")
            let decoder = JSONDecoder()
            let ans = try decoder.decode(Credentials.self, from: archived)
            Logger.log("Credentials found and decoded.  They expire at \(ans.expires)")
            Logger.log("Date/time now is \(Date.now)")
            guard ans.expires > Date.now else {
                Logger.log("credentials expired")
                return nil
            }
            return ans
        } catch {
            Logger.log("Credentials not found on disk")
            return nil
        }
    }
    
    // Store a new set of credentials
    func store(_ creds: Credentials) -> Bool {
        let encoder = JSONEncoder()
        guard let encoded = try? encoder.encode(creds) else { return false }
        let storageFile = getDocDirectory().appendingPathComponent(CredentialsFile).path
        FileManager.default.createFile(atPath: storageFile, contents: encoded, attributes: nil)
        return true
    }
    
    // Perform login.
    // Errors here do not terminate the app but report the error and leave credentials at nil.
    // The app should still be usable but only in solitaire or "Nearby Only" mode.
    func login(_ provider: TokenProvider) async -> Error? {
        let result = await provider.login()
        switch result {
        case let .success(creds):
            if !self.store(creds) {
                Logger.log("Failed to store apparently valid credentials when performing login")
            }
            return nil
        case let.failure(error):
            return error
        }
    }
}
