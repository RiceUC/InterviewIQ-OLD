import SwiftUI

// Reusable 1–5 star rating picker. Tapping a star sets the rating.
struct StarRatingView: View {
    @Binding var rating: Int
    var maxStars: Int = 5
    var starSize: CGFloat = 28

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxStars, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: starSize))
                    .foregroundStyle(star <= rating ? Color.yellow : Color.secondary)
                    .onTapGesture { rating = star }
            }
        }
    }
}
