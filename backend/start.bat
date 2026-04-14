@echo off
echo Starting Stock Management Backend Server...
echo.

if not exist node_modules (
    echo Installing dependencies...
    call npm install
    echo.
)

if not exist .env (
    echo Creating .env file from env.example...
    if exist env.example (
        copy env.example .env
    ) else (
        echo PORT=5000 > .env
        echo MONGODB_URI=mongodb://localhost:27017/stock_management >> .env
        echo JWT_SECRET=your_super_secret_jwt_key_change_in_production >> .env
        echo JWT_EXPIRE=7d >> .env
        echo NODE_ENV=development >> .env
    )
    echo.
    echo Please edit .env file with your MongoDB connection string and JWT secret!
    echo.
    pause
)

echo Starting server...
node server.js

