# Magizh POS 🍔🍟

A high-performance, modern Point of Sale (POS) system built with Flutter and Supabase. Optimized for speed, reliability, and professional checkout flows.

## 🚀 Features

- **Modern UI/UX**: Premium design system with staggered animations and haptic feedback.
- **Inventory Management**: Real-time stock tracking and easy product management.
- **Expense Tracking**: Automated sales logging and history.
- **Professional Checkout**:
    - Dual payment methods (Online/Cash).
    - **Live Cash Flow**: Automatic "Change to Return" calculator.
    - Automatic stock deduction upon successful order.
- **Future-Proof Build**: Fully migrated to Flutter's Built-in Kotlin and modern Gradle DSL.

## 🛠 Tech Stack

- **Frontend**: Flutter (3.x)
- **State Management**: Riverpod (3.0+)
- **Backend**: Supabase (Database, Auth, Storage)
- **Theming**: Custom Premium Design System

## 📦 Setup Instructions

Follow these steps to run the project on your machine:

1. **Prerequisites**: Ensure you have [Flutter](https://docs.flutter.dev/get-started/install) installed.
2. **Clone the project**:
   ```bash
   git clone <repository-url>
   cd Magizh
   ```
3. **Environment Variables**:
   - Create a file named `.env` in the root directory.
   - Copy the contents from `.env.example` into `.env`.
   - Replace the placeholders with your actual Supabase URL and Anon Key.
4. **Install Dependencies**:
   ```bash
   flutter pub get
   ```
5. **Run the App**:
   ```bash
   flutter run
   ```

## 📂 Project Structure

- `lib/main.dart`: Home Dashboard and Core Navigation.
- `lib/checkout_sheet.dart`: Checkout logic and Cash flow.
- `lib/inventory_sheet.dart`: Product and Stock management.
- `lib/expenses_page.dart`: Transaction history.
- `lib/theme/`: Centralized Design System.

---
Built with ❤️ for Magizh.
