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

// Support for secure authentication and authorization to the server

// Errors during token provider operations
struct CredentialError: LocalizedError {
    let message: String
    init(_ message: String) {
        self.message = message
    }
    var errorDescription: String? {
        message
    }
    
    static let WrongCredentialsType = CredentialError("Attempt to store credentials of Wrong type")
    static let CouldNotStore = CredentialError("Could not store credentials")
    static let LogoutFailure = CredentialError("Failure during logout")
}

// A provider for access tokens (capable of being used as bearer tokens when contacting the server)
// The tokens must be valid for the servers you will employ.  For the Auth0 implemention:
//   -- the token must claim the same audience as the servers expect
//   -- the servers must use the Auth0 domain specified in Auth0.plist.
// When using the full unigame framework (with my provided unigame-server), the Auth0
//   implementation is required and the default audience must be used.
public protocol TokenProvider: Sendable {
    // Get new Credentials when you have none
    func login() async -> Error?
    
    // Drop any stored credentials and remove any session cookies
    func logout() async -> Error?
    
    // Check if you have valid stored credentials.  If this returns false, use 'login' to recover.
    var hasValid: Bool { get }
    
    // Check if credentials are renewable
    // (This is used as a sanity-check.  Normally, credentials _must_ be renewable).
    var canRenew: Bool { get }
    
    // Retrieve a stored valid access token.  Should work iff hasValid is true
    func accessToken() async -> Result<String, Error>
}
