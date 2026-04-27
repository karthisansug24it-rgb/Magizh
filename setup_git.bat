@echo off
cd /d "d:\மகிழ் (Magizh)"

echo === Step 1: Checking git status ===
git status

echo.
echo === Step 2: Checking git config ===
git config --list | findstr "user."

echo.
echo === Step 3: Adding remote (if not exists) ===
git remote remove origin 2>nul
git remote add origin https://github.com/karthisansug24it-rgb/Magizh.git

echo.
echo === Step 4: Adding all files ===
git add .

echo.
echo === Step 5: Git status before commit ===
git status

echo.
echo === Step 6: Creating initial commit ===
git commit -m "Initial commit: Magizh POS application with Flutter - Flutter project with Material Design - Product catalog with categories (Puff, Samosa, Roll, Drinks) - Image assets and UI components - Ready for feature development"

echo.
echo === Step 7: Setting branch to main ===
git branch -M main

echo.
echo === Step 8: Pushing to GitHub ===
git push -u origin main

echo.
echo === Step 9: Git log ===
git log --oneline -5

echo.
echo === Setup Complete ===
pause
