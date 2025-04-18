//
//  CredentialStore.swift
//  anyCards
//
//  Created by Josh Auerbach on 4/24/24.
//

import Foundation
import Auth0
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
    public init(audience: String) {
        self.audience = audience
    }
    public convenience init() {
        self.init(audience: DefaultAudience)
    }
    public func login() async -> Result<Credentials, Error> {
        do {
            let auth0creds = try await Auth0.webAuth().useHTTPS().audience(audience).start()
            let credentials = Credentials(accessToken: auth0creds.accessToken, expires: auth0creds.expiresIn)
            return .success(credentials)
        } catch {
            return .failure(error)
        }
    }
    
    public func logout() async -> Error? {
        do {
            try await Auth0.webAuth().useHTTPS().clearSession(federated: false)
            return nil
        } catch {
            return error
        }
    }
}
