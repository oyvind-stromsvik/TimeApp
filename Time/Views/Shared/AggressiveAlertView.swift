import SwiftUI

struct AggressiveAlertView: View {
    var onDismiss: () -> Void
    
    @State private var isFlashing = false
    @State private var textScale: CGFloat = 1.0
    @State private var offset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Panic Mode Background: Flashes between Red and Black
            Color(isFlashing ? .systemRed : .black)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true), value: isFlashing)
            
            VStack(spacing: 30) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(.yellow)
                    .symbolEffect(.pulse, options: .repeating.speed(2.0))
                    .shadow(color: .black, radius: 2, x: 0, y: 2)
                
                VStack(spacing: 10) {
                    Text("STOP SLACKING OFF!")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .scaleEffect(textScale)
                    
                    Text("WHY AREN'T YOU WORKING?")
                        .font(.system(size: 32, weight: .heavy, design: .default))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                
                Text("Time is ticking. Track your task NOW.")
                    .font(.title2.bold())
                    .foregroundStyle(.black)
                
                Button {
                    onDismiss()
                } label: {
                    Text("I'LL START TRACKING")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .padding(.vertical, 20)
                        .padding(.horizontal, 40)
                        .background(
                            Rectangle()
                                .fill(Color.red)
                                .shadow(radius: 10)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 20)
            }
            .padding(50)
            .background(Color.white) // Hardcoded white background for maximum contrast
            .border(Color.red, width: 10)
            .shadow(radius: 20)
            .offset(x: offset)
        }
        .onAppear {
            isFlashing = true
            NSSound.beep()
            
            // Text Pulse Animation
            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                textScale = 1.1
            }
            
            // Violent Shake Animation
            let shake = Animation.spring(response: 0.1, dampingFraction: 0.1, blendDuration: 0).repeatCount(10)
            withAnimation(shake) {
                offset = 20
            } completion: {
                offset = 0
            }
        }
    }
}

#Preview {
    AggressiveAlertView(onDismiss: {})
}
