package com.example.apk.config

object Config {
    // Supabase configuration
    // For mobile and desktop apps, prefer using the publishable key (anon key)
    // You can get these from your Supabase project settings: Settings → API
    const val SUPABASE_URL = "https://vwagtikpxbhjrffolrqn.supabase.co"
    const val SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ3YWd0aWtweGJoanJmZm9scnFuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3ODE0NDksImV4cCI6MjA3NDM1NzQ0OX0.cYevGkIj1HkjKv7iC14TgR7ItGF6YnXJi5Qw6ONYmcQ"
    
    // API configuration
    // Production backend API endpoint
    // Note: Retrofit requires trailing slash for base URL when using absolute paths
    val apiBaseUrl: String
        get() = "http://bwkcw0s0g0csk8cg8o88ckoc.192.168.68.113.sslip.io/"
    
    // OAuth redirect URL for Google Sign In
    const val OAUTH_REDIRECT_URL = "com.example.apk://login-callback/"
}


