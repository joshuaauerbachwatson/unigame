//
//  CredentialStore.swift
//  anyCards
//
//  Created by Josh Auerbach on 4/24/24.
//

import Foundation
@preconcurrency import Auth0
import AuerbachLook

// An Auth0 implementation of unigame TokenProvider.  An app that wishes to use this TokenProvider
// must obtain an Auth0 application which has been configured to work with the bundle id of the app.
// Then, an Auth0.plist file must be made available as a resource, containing a clientId and domain
// matching the Auth0 application.  Finally, the entitlements of the app must include an associated
// domain entry naming the Auth0 domain so that callbacks work.  See Auth0 documentation.

// This support may be used without necessarily using the rest of the unigame framework.

// The audience claim expected by unigame-server
fileprivate let DefaultAudience = "https://unigame.com"

extension Auth0.Credentials: Credentials, @retroactive @unchecked Sendable {
    public var expires: Date {
        expiresIn
    }
}

public final class Auth0TokenProvider: TokenProvider {
    let audience: String
    let credentialsManager = CredentialsManager(authentication: Auth0.authentication())
    
    public init(audience: String? = nil) {
        self.audience = audience ?? DefaultAudience
    }

    public func login() async -> Result<Credentials, Error> {
        do {
            let credentials = try await Auth0.webAuth()
                .useEphemeralSession().useHTTPS().audience(audience)
                .scope("openid profile offline_access").start()
            return .success(credentials)
        } catch {
            return .failure(error)
        }
    }
    
    public func logout() async -> Error? {
        if credentialsManager.clear() {
            return nil
        }
        return CredentialError.LogoutFailure
    }

    public func store(_ creds: any Credentials) -> (any Error)? {
        if let credentials = creds as? Auth0.Credentials {
            Logger.log("Storing Auth0 credentials: \(credentials)")
            if credentialsManager.store(credentials: credentials) {
                return nil
            }
            return CredentialError.CouldNotStore
        }
        return CredentialError.WrongCredentialsType
    }
    
    public func hasValid() -> Bool {
        credentialsManager.hasValid()
    }
    
    public func canRenew() -> Bool {
        credentialsManager.canRenew()
    }
    
    public func credentials() async -> Result<any Credentials, Error> {
        do {
            let creds = try await credentialsManager.credentials()
            return .success(creds)
        } catch {
            return .failure(error)
        }
    }
}
