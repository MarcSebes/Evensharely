//
//  SignInView.swift
//  Evensharely
//
//  Updated on 5/8/25 with correct onCompletion handling

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject private var auth: AuthenticationViewModel

    var body: some View {
        VStack(spacing: 32) {
            Text("Welcome to SquirrelBear!")
                .font(.largeTitle).bold()

            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    print("[SignInView] onRequest: configuring scopes")
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    print("[SignInView] onCompletion: \(result)")
                    switch result {
                    case .success(let authorization):
                        auth.handle(credentialResult: authorization)
                    case .failure(let error):
                        print("[SignInView] Sign in failed: \(error)")
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 44)
            .padding(.horizontal)
        }
    }
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView()
            .environmentObject(AuthenticationViewModel())
    }
}
