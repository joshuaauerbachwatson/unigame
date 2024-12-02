//
//  CredentialStore.swift
//  anyCards
//
//  Created by Josh Auerbach on 4/24/24.
//

import Foundation
import Auth0
import AuerbachLook

// An Auth0 implementation of unigame TokenProvider.  An app that wishes to use this TokenProvider must obtain
// an Auth0 application which aligns with the bundle id of the app.  Then, an Auth0.plist file must
// be available as a resource, containing a clientId and domain matching the Auth0 application.
public final class Auth0TokenProvider: TokenProvider {
    public func login() async -> Result<Credentials, Error> {
        do {
            let auth0creds = try await Auth0.webAuth().useHTTPS().audience("https://unigame.com").start()
            let credentials = Credentials(accessToken: auth0creds.accessToken, expires: auth0creds.expiresIn)
            return .success(credentials)
        } catch {
            return .failure(error)
        }
    }
}
