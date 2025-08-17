-- 1. Create the database with US English UTF-8 locale
CREATE DATABASE final_project
    WITH ENCODING 'UTF8'
    LC_COLLATE 'en_US.UTF-8'
    LC_CTYPE 'en_US.UTF-8'
    TEMPLATE template0;

-- 2. Connect to the new database
\c final_project;

-- 3. Create table of users
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_staff BOOLEAN DEFAULT FALSE,
    is_superuser BOOLEAN DEFAULT FALSE,
    last_login TIMESTAMP,
    date_joined TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    email VARCHAR(255) UNIQUE,
    CONSTRAINT email_check CHECK (email IS NULL OR email != '')
);

-- 4. Create table for sessions
CREATE TABLE django_session (
    session_key VARCHAR(40) PRIMARY KEY,
    session_data TEXT NOT NULL,
    expire_date TIMESTAMP NOT NULL
);

-- 5. Create table for records
CREATE TABLE records (
    id SERIAL PRIMARY KEY,
    registry_type VARCHAR(20) CHECK (registry_type IN ('maintenance', 'breakdown', 'consumption')) NOT NULL,
    mileage INTEGER NOT NULL,
    price DECIMAL(10, 2),
    date DATE NOT NULL,
    details TEXT,
    user_id INTEGER NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 6. Create table for cars
CREATE TABLE cars (
    id SERIAL PRIMARY KEY,
    brand VARCHAR(50) NOT NULL,
    model VARCHAR(100) NOT NULL,
    year INT CHECK (year BETWEEN 1900 AND 2025),
    engine VARCHAR(100),
    fuel VARCHAR(10) CHECK (fuel IN ('gasoline', 'diesel', '*')),
    user_id INTEGER UNIQUE NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CHECK (brand IN (
        'Toyota', 'Ford', 'Volkswagen', 'Honda', 'Chevrolet', 'Nissan', 'BMW', 'Mercedes-Benz', 'Audi',
        'Hyundai', 'Kia', 'Peugeot', 'Renault', 'Fiat', 'Skoda', 'SEAT', 'Mazda', 'Subaru', 'Mitsubishi',
        'Tesla', 'Volvo', 'Jeep', 'Dodge', 'Ram', 'Chrysler', 'Buick', 'Cadillac', 'Lincoln', 'GMC',
        'Land Rover', 'Jaguar', 'Alfa Romeo', 'Maserati', 'Ferrari', 'Lamborghini', 'Porsche',
        'Aston Martin', 'Bentley', 'Rolls-Royce', 'Bugatti', 'McLaren', 'Lotus', 'Mini', 'Smart',
        'Citroën', 'DS Automobiles', 'Genesis', 'Infiniti', 'Acura', 'Daihatsu', 'Proton', 'Perodua',
        'Geely', 'Chery', 'BYD', 'NIO', 'Xpeng', 'Li Auto', 'Great Wall Motors', 'Haval', 'BAIC',
        'FAW', 'Hongqi', 'Roewe', 'MG (Morris Garages)', 'Lancia', 'Dacia', 'Tata Motors', 'Mahindra',
        'Maruti Suzuki', 'Scion', 'Pontiac', 'Saturn', 'Hummer', 'Daewoo', 'Oldsmobile', 'Isuzu',
        'Suzuki', 'Yugo', 'Zastava', 'Koenigsegg', 'Rimac', 'Fisker', 'Lucid Motors', 'Polestar',
        'Rivian', 'Ariel', 'Pagani', 'Spyker', 'Noble', 'De Tomaso', 'Saleen', 'Pininfarina',
        'SSC North America', 'Gumpert', 'Aptera', 'Bollinger Motors', 'Canoo', 'VinFast', 'Zenos',
        'Faraday Future', 'Rezvani', 'W Motors', 'TVR', 'Brilliance Auto', 'Luxgen', 'Togg',
        'Donkervoort', 'Hispano Suiza', 'Ginetta', '*'
    ))
);

-- 7. Insert test users
INSERT INTO users (username, password, is_active, is_staff, is_superuser, email) VALUES
('juan', 'pbkdf2_sha256$1000000$tPElqMILDAAjL5e8boLnGe$e3K/g85W217Af31g9lwWvRHXr0vvDDOfd1+ZyBSlHno=', TRUE, FALSE, FALSE, 'juan@email.com'),
('maria', 'pbkdf2_sha256$1000000$o28NgNUIGi9HEHiDWxuQpe$I8ZxxR8ogNPFA8mTlicaBiFABAXiJEASyrXWIGbDrG8=', TRUE, FALSE, FALSE, 'maria@email.com');

-- 8. Insert records for Juan
INSERT INTO records (registry_type, mileage, price, date, details, user_id) VALUES
('maintenance', 12000, 250.00, '2024-10-15', 'Oil and filter change', 1),
('breakdown', 13500, 400.00, '2024-12-01', 'Brake system failure', 1),
('consumption', 14000, 60.00, '2025-01-20', 'Fuel fill-up', 1);

-- 9. Insert records for Maria
INSERT INTO records (registry_type, mileage, price, date, details, user_id) VALUES
('maintenance', 10000, 180.00, '2024-11-05', 'General inspection', 2),
('breakdown', 11000, 320.00, '2025-02-10', 'Transmission problem', 2),
('consumption', 11500, 55.00, '2025-03-01', 'Highway refueling', 2);

-- 10. Insert car for Juan
INSERT INTO cars (brand, model, year, engine, fuel, user_id) VALUES
('Toyota', 'Corolla', 2020, '1.8L Hybrid', 'gasoline', 1);

-- 11. Insert car for Maria
INSERT INTO cars (brand, model, year, engine, fuel, user_id) VALUES
('Volkswagen', 'Golf', 2019, '2.0 TDI', 'diesel', 2);
