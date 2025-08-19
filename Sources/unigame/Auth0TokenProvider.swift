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

public final class Auth0TokenProvider: TokenProvider {
    let audience: String
    let credentialsManager = CredentialsManager(authentication: Auth0.authentication())
    
    public init(audience: String? = nil) {
        self.audience = audience ?? DefaultAudience
    }

    public func login() async -> Error? {
        do {
            let credentials = try await Auth0.webAuth()
                .useEphemeralSession().useHTTPS().audience(audience)
                .scope("openid profile offline_access").start()
            if !credentialsManager.store(credentials: credentials) {
                return CredentialError.CouldNotStore
            }
            return nil
        } catch {
            return error
        }
    }
    
    public func logout() async -> Error? {
        if credentialsManager.clear() {
            return nil
        }
        return CredentialError.LogoutFailure
    }
    
    public var canRenew: Bool {
        credentialsManager.canRenew()
    }
    
    public func accessToken() async -> Result<String, Error> {
        do {
            let creds = try await credentialsManager.credentials()
            return .success(creds.accessToken)
        } catch {
            return .failure(error)
        }
    }
}
