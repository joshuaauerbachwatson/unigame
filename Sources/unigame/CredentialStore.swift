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

// This support may be used without necessarily using the rest of the unigame framework.

fileprivate let CredentialsFile = "credentials"

// The stored credentials
public struct Credentials: Codable, Sendable {
    public let accessToken: String
    public let expires: Date
    public var valid: Bool {
        expires > Date.now
    }
    public init(accessToken: String, expires: Date) {
        self.accessToken = accessToken
        self.expires = expires
    }
}

// A provider for the token when an unexpired one is not found stored locally.
// The token must be valid for the servers you will employ.  For the Auth0 implemention:
//   -- the token must claim the same audience as the servers expect
//   -- the servers must use the domain specified in Auth0.plist.
// When using the full unigame framework (with unigame-server), and retaining the Auth0
//   implementation, the default audience must be used.
public protocol TokenProvider: Sendable {
    func login() async -> Result<Credentials, Error>
    func logout() async -> Error?
}

// Provides load and store operations for Credentials.
public class CredentialStore {
    static let storageFile = getDocDirectory().appendingPathComponent(CredentialsFile)

    // Load function.  Returns the current stored credentials or nil.
    public class func load() -> Credentials? {
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
    
    // Remove the credential store (usually as part of logout)
    class func remove() -> Error? {
        do {
            try FileManager.default.removeItem(at: storageFile)
            return nil
        } catch {
            return error
        }
    }
    
    // Store a new set of credentials (usually as part of login)
    class func store(_ creds: Credentials) -> Bool {
        let encoder = JSONEncoder()
        guard let encoded = try? encoder.encode(creds) else { return false }
        FileManager.default.createFile(atPath: storageFile.path, contents: encoded, attributes: nil)
        return true
    }
    
    // Do the login operation
    public class func login(_ tokenProvider: TokenProvider) async -> Result<Credentials, Error> {
        Logger.log("Logging in")
        let result = await tokenProvider.login()
        switch result {
        case let .success(creds):
            Logger.log("Login was successful")
            if !CredentialStore.store(creds) {
                Logger.log("Failed to store apparently valid credentials when performing login")
            }
            return .success(creds)
        case let.failure(error):
            Logger.log("Login failed: \(error)")
            return .failure(error)
        }
    }
    
    // Do the logout operation
    public class func logout(_ tokenProvider: TokenProvider) async -> Error? {
        Logger.log("Logging out")
        // Try to logout from the token provider
        if let err = await tokenProvider.logout() {
            Logger.log("Logout failed: \(err)")
            return err
        }
        // Logout succeeded.  Try to remove credential store
        if let err = remove() {
            Logger.log("Credential store could not be removed")
            return err
        }
        return nil
    }
}
