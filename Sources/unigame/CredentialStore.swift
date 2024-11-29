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

// Manage Auth0-provided credentials

fileprivate let CredentialsFile = "credentials"

// The stored credentials.  Although the token must be valid for Auth0 (which is used by the server)
// we don't need Auth0 login details here because those will be app-specific.  So, we use our own structure
// which is not the Auth0 credentials structure.
public struct Credentials: Codable {
    public let accessToken: String
    public let expiresIn: Date
    public init(accessToken: String, expiresIn: Date) {
        self.accessToken = accessToken
        self.expiresIn = expiresIn
    }
}

// A provider for the token.  The token must be valid for the Auth0 "audience" https://unigame.com
// in order to validate at the server.  However, this package does not depend directly on Auth0 nor
// does it provide an auth0.plist because each app must use its own Auth0 application profiles (and
// perhaps even different tenants (TBD)).
public protocol TokenProvider: Sendable {
    func login() async -> (Credentials?, LocalizedError?)
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
            Logger.log("Credentials found and decoded.  They expire at \(ans.expiresIn)")
            Logger.log("Date/time now is \(Date.now)")
            guard ans.expiresIn > Date.now else {
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
    
    // Perform login iff there are not already valid credentials present.
    // Since the actual login handshake is asynchronous, the processing that requires the credentials
    // should take place in the handler up to the next point where user interaction is required.
    // Errors here do not terminate the app but report the error and leave credentials at nil.
    // The app should still be usable but only in solitaire or "Nearby Only" mode.
    func loginIfNeeded(_ provider: TokenProvider) async -> (Credentials?, LocalizedError?) {
        // Test for already present
        if let already = credentials, already.expiresIn > Date.now {
            // Login not needed
            Logger.log("Using credentials already stored")
            return (already, nil)
        }
        // Do actual login, storing the result if successful
        let (creds, err) = await provider.login()
        if let creds = creds {
            if !self.store(creds) {
                 Logger.log("Failed to store apparently valid credentials when performing login")
            }
        }
        return (creds, err)
    }
}
