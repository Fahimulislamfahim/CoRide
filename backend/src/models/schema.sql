-- CoRide Database Schema DDL
-- For Daffodil International University Ridesharing App

-- Enable UUID extension if not enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop tables if they exist (for clean setup)
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS ride_requests CASCADE;
DROP TABLE IF EXISTS rides CASCADE;
DROP TABLE IF EXISTS hubs CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- 1. Hubs Table (Dynamic Locations)
CREATE TABLE hubs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) UNIQUE NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL
);

-- Insert Default DIU Hubs
INSERT INTO hubs (name, lat, lng) VALUES
('Mirpur 10 Hub', 23.8069, 90.3687),
('Uttara House Building Hub', 23.8729, 90.4007),
('Dhanmondi 27 Hub', 23.7538, 90.3768),
('Savar Bus Stand Hub', 23.8442, 90.2581),
('DIU Smart City (Ashulia)', 23.8767, 90.3201);


-- 2. Users Table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    student_id VARCHAR(50) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('Rider', 'Passenger', 'Both')),
    rating DECIMAL(3, 2) DEFAULT 5.00 CHECK (rating >= 0.00 AND rating <= 5.00),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_diu_email CHECK (email LIKE '%@diu.edu.bd')
);

-- Index for authentication lookup
CREATE INDEX idx_users_email ON users(email);

-- 3. Rides Table
CREATE TABLE rides (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rider_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    origin_name VARCHAR(255) NOT NULL,
    origin_lat DOUBLE PRECISION NOT NULL,
    origin_lng DOUBLE PRECISION NOT NULL,
    destination_name VARCHAR(255) NOT NULL,
    destination_lat DOUBLE PRECISION NOT NULL,
    destination_lng DOUBLE PRECISION NOT NULL,
    departure_time TIMESTAMP WITH TIME ZONE NOT NULL,
    vehicle_type VARCHAR(10) NOT NULL CHECK (vehicle_type IN ('Bike', 'Car')),
    available_seats INTEGER NOT NULL CHECK (available_seats >= 0),
    helmet_provided BOOLEAN NOT NULL DEFAULT FALSE,
    offered_fare DECIMAL(10, 2) NOT NULL CHECK (offered_fare > 0), -- Base fare rider asks for
    status VARCHAR(20) NOT NULL DEFAULT 'Scheduled' CHECK (status IN ('Scheduled', 'Active', 'Completed', 'Cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Business logic constraints
    CONSTRAINT check_bike_seats CHECK (
        (vehicle_type = 'Bike' AND available_seats <= 1) OR 
        (vehicle_type = 'Car' AND available_seats <= 4)
    )
);

-- Indexes for fast queries
CREATE INDEX idx_rides_rider ON rides(rider_id);
CREATE INDEX idx_rides_status_departure ON rides(status, departure_time);
CREATE INDEX idx_rides_origin_dest ON rides(origin_lat, origin_lng, destination_lat, destination_lng);

-- 4. Ride Requests (Bidding System) Table
CREATE TABLE ride_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
    passenger_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Accepted', 'Rejected', 'Cancelled')),

    -- Bidding tracking
    proposed_fare DECIMAL(10, 2) NOT NULL CHECK (proposed_fare > 0.00),
    bid_status VARCHAR(30) NOT NULL DEFAULT 'Initial' CHECK (bid_status IN ('Initial', 'Passenger_Counter', 'Rider_Counter', 'Accepted', 'Rejected_Limit_Reached', 'Rejected_By_Rider', 'Rejected_By_Passenger')),
    passenger_bids_count INTEGER NOT NULL DEFAULT 0 CHECK (passenger_bids_count <= 2),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Ensure same user cannot request the same ride multiple times
    CONSTRAINT unique_passenger_ride UNIQUE (ride_id, passenger_id)
);

-- Indexes for requests lookup
CREATE INDEX idx_ride_requests_ride ON ride_requests(ride_id);
CREATE INDEX idx_ride_requests_passenger ON ride_requests(passenger_id);

-- 5. Reviews Table
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
    reviewer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reviewee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- A user can only review another user once per ride
    CONSTRAINT unique_ride_review UNIQUE (ride_id, reviewer_id, reviewee_id)
);

CREATE INDEX idx_reviews_reviewee ON reviews(reviewee_id);
