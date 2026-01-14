import asyncio
import os
import sys
from pathlib import Path
import asyncpg
from dotenv import load_dotenv

async def run_migrations():
    # Load .env from backend directory
    backend_dir = Path(__file__).resolve().parents[2]
    env_path = backend_dir / ".env"
    
    if env_path.exists():
        load_dotenv(env_path)
    else:
        print(f"ERROR: .env not found at {env_path}")
        sys.exit(1)

    postgres_url = os.environ.get("POSTGRES_URL")
    if not postgres_url:
        print("ERROR: POSTGRES_URL not set in environment")
        sys.exit(1)

    migrations_dir = backend_dir / "migrations"
    if not migrations_dir.exists():
        print(f"ERROR: Migrations directory not found at {migrations_dir}")
        sys.exit(1)

    # Get sorted migration files
    migrations = sorted(list(migrations_dir.glob("*.sql")))
    if not migrations:
        print("No migration files found.")
        return

    print(f"Found {len(migrations)} migration files.")

    try:
        conn = await asyncpg.connect(postgres_url)
        print("Connected to database.")
    except Exception as e:
        print(f"ERROR: Could not connect to database: {e}")
        sys.exit(1)

    try:
        for migration_path in migrations:
            migration_name = migration_path.name
            print(f"Running {migration_name}...")
            
            with open(migration_path, "r") as f:
                sql = f.read()

            try:
                # Use a transaction for each migration
                async with conn.transaction():
                    await conn.execute(sql)
                print(f"✅ {migration_name} completed.")
            except Exception as e:
                # Check for common "already exists" errors to be idempotent
                error_msg = str(e).lower()
                if "already exists" in error_msg or "duplicate" in error_msg:
                    print(f"⚠️  {migration_name} already applied or partial overlap (skipping error: {e})")
                else:
                    print(f"❌ {migration_name} failed: {e}")
                    sys.exit(1)
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(run_migrations())
