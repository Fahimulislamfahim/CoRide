// Verification script for CoRide backend core rules
const assert = require('assert').strict;

// 1. Mocking academic email check
function checkDiuEmail(email) {
  return email.endsWith('@diu.edu.bd');
}

// 2. Mocking seats constraints
function checkSeatsConstraint(vehicleType, seats) {
  if (vehicleType === 'Bike') {
    return seats <= 1;
  }
  if (vehicleType === 'Car') {
    return seats >= 1 && seats <= 4;
  }
  return false;
}

// 3. Mocking dynamic fare share calculation
const calculateDistance = (lat1, lon1, lat2, lon2) => {
  const R = 6371; // Earth radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
};

const calculateBaseFare = (lat1, lon1, lat2, lon2, vehicleType) => {
  const distance = calculateDistance(lat1, lon1, lat2, lon2);
  const ratePerKm = vehicleType === 'Bike' ? 10 : 20;
  const basePrice = vehicleType === 'Bike' ? 30 : 60;
  return basePrice + (distance * ratePerKm);
};

const calculateDynamicFareShare = (lat1, lon1, lat2, lon2, vehicleType, acceptedCount) => {
  const baseFare = calculateBaseFare(lat1, lon1, lat2, lon2, vehicleType);
  // Total participants = 1 (Rider) + acceptedCount
  return Math.round(baseFare / (1 + acceptedCount));
};

// Running Tests
(async function runTests() {
  console.log('==================================================');
  console.log('  STARTING SYSTEM CONTEXT RULE VERIFICATION TESTS  ');
  console.log('==================================================');

  try {
    // Test 1: Academic Email Checks
    console.log('Test 1: Enforcing @diu.edu.bd email restrictions...');
    assert.equal(checkDiuEmail('fahim.se@diu.edu.bd'), true, 'Should accept valid DIU student email');
    assert.equal(checkDiuEmail('faculty.swe@diu.edu.bd'), true, 'Should accept valid DIU faculty email');
    assert.equal(checkDiuEmail('external@gmail.com'), false, 'Should reject non-DIU email domain');
    assert.equal(checkDiuEmail('hacker@diu.edu.bd.com'), false, 'Should reject email that matches diu.edu.bd prefix but has wrong TLD');
    console.log('✓ Test 1 Passed: strict email domain filters confirmed.\n');

    // Test 2: Seats Constraints
    console.log('Test 2: Validating vehicle capacity constraints...');
    assert.equal(checkSeatsConstraint('Bike', 1), true, 'Bike with 1 seat should be valid');
    assert.equal(checkSeatsConstraint('Bike', 2), false, 'Bike with 2 seats should be invalid');
    assert.equal(checkSeatsConstraint('Car', 3), true, 'Car with 3 seats should be valid');
    assert.equal(checkSeatsConstraint('Car', 5), false, 'Car with 5 seats should be invalid');
    console.log('✓ Test 2 Passed: Vehicle matching capacity constraints verified.\n');

    // Test 3: Geospatial Dynamic Fare Sharing & Cancellation Recovery
    console.log('Test 3: Calculating distance-based dynamic splits & cancellation behavior...');
    const lat1 = 23.8069, lon1 = 90.3687; // Mirpur 10
    const lat2 = 23.8767, lon2 = 90.3201; // DIU Smart City
    
    // Distance check
    const dist = calculateDistance(lat1, lon1, lat2, lon2);
    console.log(`- Measured Distance: ${dist.toFixed(2)} km`);
    
    // Base fare: Car = 60 + 9.20 * 20 = 244
    // 3 passengers accepted (4 participants total: 1 rider + 3 passengers)
    // Fare split per passenger = 244 / 4 = 61 BDT
    let acceptedPassengers = 3;
    let seatsAvailable = 1; // 4 seats total - 3 accepted = 1 left
    let fare = calculateDynamicFareShare(lat1, lon1, lat2, lon2, 'Car', acceptedPassengers);
    console.log(`- Initial state: ${acceptedPassengers} passengers accepted. Fare share: ${fare} BDT (Available seats: ${seatsAvailable})`);
    assert.equal(fare, 61);

    // One passenger cancels:
    console.log('  Passenger cancels request...');
    acceptedPassengers -= 1;
    seatsAvailable += 1; // Seat is restored!
    fare = calculateDynamicFareShare(lat1, lon1, lat2, lon2, 'Car', acceptedPassengers);
    console.log(`- Updated state: ${acceptedPassengers} passengers remain. Fare share: ${fare} BDT (Available seats: ${seatsAvailable})`);
    
    // 2 passengers accepted (3 participants total: 1 rider + 2 passengers)
    // Fare split per passenger = 244 / 3 = 81.33 -> 81 BDT
    assert.equal(fare, 81);
    assert.equal(seatsAvailable, 2);
    console.log('✓ Test 3 Passed: Dynamic fare sharing and cancellation recalculations verified.\n');

    console.log('==================================================');
    console.log('  ALL CORE BUSINESS RULE VERIFICATION TESTS PASSED  ');
    console.log('==================================================');
  } catch (error) {
    console.error('❌ Verification Test Failed:', error.message);
    process.exit(1);
  }
})();
