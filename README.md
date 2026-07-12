# CoRide - Campus-Centric Ridesharing & Carpooling

CoRide is a campus-centric ridesharing and carpooling mobile application specifically designed for Daffodil International University (DIU) students, faculty, and staff. The application facilitates safe, cost-effective, and community-driven commuting by connecting drivers (riders) and passengers traveling along similar routes.

The project is split into two main components:
1. **Frontend**: A cross-platform mobile application built using **Flutter**.
2. **Backend**: A robust REST and Real-Time WebSocket API built using **Node.js, Express, and Socket.io**, powered by a **PostgreSQL** database.

---

## Repository Structure

Click on the links below to explore the codebase directories and main files:

- [frontend/](file:///d:/projects/CoRide/frontend) — Flutter client application
  - [lib/main.dart](file:///d:/projects/CoRide/frontend/lib/main.dart) — Application entry point
  - [lib/providers/](file:///d:/projects/CoRide/frontend/lib/providers) — State management (e.g., [auth_provider.dart](file:///d:/projects/CoRide/frontend/lib/providers/auth_provider.dart))
  - [lib/screens/](file:///d:/projects/CoRide/frontend/lib/screens) — Application UI screens (onboarding, login, passenger matching, rider dashboard)
  - [lib/services/](file:///d:/projects/CoRide/frontend/lib/services) — Network handlers ([api_service.dart](file:///d:/projects/CoRide/frontend/lib/services/api_service.dart) and [socket_service.dart](file:///d:/projects/CoRide/frontend/lib/services/socket_service.dart))
  - [pubspec.yaml](file:///d:/projects/CoRide/frontend/pubspec.yaml) — Flutter dependencies configuration
- [backend/](file:///d:/projects/CoRide/backend) — Express & Socket.io server
  - [src/server.js](file:///d:/projects/CoRide/backend/src/server.js) — Server entry point and configuration
  - [src/routes/](file:///d:/projects/CoRide/backend/src/routes) — Express route handlers for [authRoutes.js](file:///d:/projects/CoRide/backend/src/routes/authRoutes.js) and [rideRoutes.js](file:///d:/projects/CoRide/backend/src/routes/rideRoutes.js)
  - [src/sockets/socketHandler.js](file:///d:/projects/CoRide/backend/src/sockets/socketHandler.js) — Real-time Socket.io event handling and caching
  - [src/models/schema.sql](file:///d:/projects/CoRide/backend/src/models/schema.sql) — PostgreSQL DDL schema definition
  - [test_verification.js](file:///d:/projects/CoRide/backend/test_verification.js) — Core business rules verification test suite

---

## Core Business Rules & System Design

CoRide enforces several strict academic, capacity, and financial guidelines:

### 1. Strict Academic Domain Restrictions
To ensure safety and community trust, account registration and WebSockets authentication strictly require academic email addresses ending with the `@diu.edu.bd` domain. Non-DIU email domains are immediately rejected during:
- Account Registration API (`POST /api/auth/register`)
- WebSocket Connection Handshake Middleware (checking `socket.handshake.auth.token`)

### 2. Vehicle Capacity Constraints
When a rider offers a ride, capacity is restricted based on the vehicle type:
- **Motorcycle (Bike)**: Maximum of **1** available seat.
- **Car**: Maximum of **4** available seats.

### 3. Geospatial Dynamic Fare Sharing
Fares are computed dynamically based on the distance between the ride origin and destination coordinates using the **Haversine formula**:
- **Pricing Model**:
  - **Bike**: 30 BDT base fare + 10 BDT/km
  - **Car**: 60 BDT base fare + 20 BDT/km
- **Dynamic Fare Split**:
  The total fare is shared equally among the rider and all accepted passengers.
  $$\text{Fare Share per Passenger} = \frac{\text{Base Fare}}{1 + \text{Accepted Passengers Count}}$$
- **Real-Time Recalculation & Restoration**:
  When a passenger cancels their request, their seat is restored, and the fare is dynamically recalculated (increased) in real-time for the remaining passengers.

---

## Real-Time Tracking & WebSocket API

WebSocket connections are managed in [socketHandler.js](file:///d:/projects/CoRide/backend/src/sockets/socketHandler.js) and support the following features:

### Handshake Authentication
Requires passing a valid JWT token in `auth.token`. The server decodes it and verifies that the email ends with `@diu.edu.bd`.

### WebSocket Events
- **`join_ride_room` (Client $\rightarrow$ Server)**: Emitted by passengers or riders to join a specific ride room using a `rideId`. 
  - *Response*: If the server has a cached location for that ride, it immediately emits `location_update` back to the client. It also broadcasts `member_joined` to other room members.
- **`update_location` (Client $\rightarrow$ Server)**: Emitted by the driver to report their coordinates (`lat`, `lng`), `speed`, and `rideId`.
  - *Throttling*: The server enforces a strict **5-second throttle limit** per ride to conserve bandwidth.
  - *Geospatial Dropout Protection*: The last known location is cached in memory. If a client disconnects briefly (e.g., due to weak signals on the DIU Smart City embankment road), their last known location is immediately re-sent when they re-join.
- **`ride_status_changed` (Client $\rightarrow$ Server)**: Sent to signal a change in ride state (`Scheduled`, `Active`, `Completed`, `Cancelled`).
  - *State Sync*: Broadcasts `status_update` with the new status to everyone in the room.
  - *Cleanup*: If the status changes to `Completed` or `Cancelled`, cached location data for that ride is cleared from the server memory.

---

## REST API Endpoints

All ride-related endpoints require a valid JWT token in the `Authorization: Bearer <token>` header.

### Authentication (`/api/auth`)
- `POST /api/auth/register` — Registers a new user. Expects `name`, `email` (must end with `@diu.edu.bd`), `password`, `student_id`, `phone`, and `role` (`Rider`, `Passenger`, `Both`). Protected by a brute-force rate limiter.
- `POST /api/auth/login` — Authenticates user credentials and returns a JWT token.

### Rides (`/api/rides`)
- `POST /api/rides/offer` — Creates a new ride offer. Requires origin, destination, departure time, vehicle type, and available seats.
- `GET /api/rides/active` — Retrieves a list of all currently available/scheduled rides.
- `POST /api/rides/request` — Requests to join a specific ride.
- `POST /api/rides/cancel-request` — Cancels a passenger's ride request. Recalculates seat capacity and dynamic fares.
- `POST /api/rides/respond` — Allows the driver to accept or reject a pending request.
- `PATCH /api/rides/status` — Updates the status of an ongoing ride.
- `GET /api/rides/:id` — Gets details of a specific ride.

---

## Setup & Installation

### Backend Setup
1. **Prerequisites**: Node.js (>=18.0.0) and PostgreSQL installed and running.
2. Navigate to the backend directory:
   ```bash
   cd backend
   ```
3. Install dependencies:
   ```bash
   npm install
   ```
4. Create a `.env` file in the `backend/` root directory and set the variables:
   ```env
   PORT=5000
   DATABASE_URL=postgresql://username:password@localhost:5432/coride_db
   JWT_SECRET=your_jwt_secret_key
   NODE_ENV=development
   ```
5. Initialize the database schema:
   ```bash
   psql -U username -d coride_db -f src/models/schema.sql
   ```
6. Start the development server:
   ```bash
   npm run dev
   ```
7. Run the verification tests to ensure everything is set up correctly:
   ```bash
   node test_verification.js
   ```

### Frontend Setup
1. **Prerequisites**: Flutter SDK (>=3.0.0) installed.
2. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```
3. Fetch packages:
   ```bash
   flutter pub get
   ```
4. Configure API base URL in [api_service.dart](file:///d:/projects/CoRide/frontend/lib/services/api_service.dart) to point to your backend (use `10.0.2.2` for Android Emulator or your local IP address for physical devices).
5. Run the application:
   ```bash
   flutter run
   ```
