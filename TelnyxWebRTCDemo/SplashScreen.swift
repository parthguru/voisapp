import SwiftUI

struct SplashScreen: View {
    @State private var isActive = false
    
    var body: some View {
        if isActive {
            // Modern SwiftUI Interface using HomeViewController
            ModernHomeView()
        } else {
            VStack {
                Image("telnyx-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .onAppear {
                NSLog("🔵 UI: SplashScreen - Splash screen appeared, starting 2 second timer")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    NSLog("🔵 UI: SplashScreen - Timer completed, transitioning to modern HomeViewController")
                    withAnimation {
                        NSLog("🔵 UI: SplashScreen - Animation started, setting isActive = true")
                        self.isActive = true
                        NSLog("🔵 UI: SplashScreen - CRITICAL TRANSITION: Legacy UIKit -> Modern SwiftUI completed")
                    }
                }
            }
        }
    }
}

struct ModernHomeView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        NSLog("🔵 UI: SplashScreen - Creating HomeViewController - Modern SwiftUI Interface")
        let homeViewController = HomeViewController()
        NSLog("🔵 UI: SplashScreen - HomeViewController created successfully")
        return homeViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        NSLog("🔵 UI: SplashScreen - UpdateUIViewController called for HomeViewController")
    }
}

struct SplashScreen_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreen()
    }
}