//
//  InterviewIQApp.swift
//  InterviewIQ
//
//  Created by Clarice Harijanto on 04/05/26.
//https://github.com/firebase/firebase-ios-sdk

import SwiftUI
import FirebaseCore


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()

        return true
    }
}

@main
struct YourApp: App {
  // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate


    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
        }
    }
}