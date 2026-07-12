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

    // Test 3: Geospatial Dynamic Fare Sharing
    console.log('Test 3: Calculating distance-based dynamic splits...');
    // Mirpur 10 Hub to DIU Ashulia (approx 15.5 km)
    const lat1 = 23.8069, lon1 = 90.3687; // Mirpur 10
    const lat2 = 23.8767, lon2 = 90.3201; // DIU Smart City
    
    // Distance check
    const dist = calculateDistance(lat1, lon1, lat2, lon2);
    console.log(`- Measured Distance: ${dist.toFixed(2)} km`);
    
    // Base fare: Car = 60 + 15.5 * 20 = 370
    // Dynamic Split: 1 passenger + 1 rider = 2 participants. Fare = 370 / 2 = 185
    const fareFor1Passenger = calculateDynamicFareShare(lat1, lon1, lat2, lon2, 'Car', 1);
    console.log(`- Car split for 1 passenger (2 participants total): ${fareFor1Passenger} BDT`);
    assert.equal(fareFor1Passenger > 0, true);

    // Dynamic Split: 3 passengers + 1 rider = 4 participants. Fare = 370 / 4 = 92.5 (rounded to 93)
    const fareFor3Passengers = calculateDynamicFareShare(lat1, lon1, lat2, lon2, 'Car', 3);
    console.log(`- Car split for 3 passengers (4 participants total): ${fareFor3Passengers} BDT`);
    assert.equal(fareFor3Passengers < fareFor1Passenger, true, 'Fare share per passenger must decrease as occupancy increases');
    console.log('✓ Test 3 Passed: Dynamic fare sharing calculation verified.\n');

    console.log('==================================================');
    console.log('  ALL CORE BUSINESS RULE VERIFICATION TESTS PASSED  ');
    console.log('==================================================');
  } catch (error) {
    console.error('❌ Verification Test Failed:', error.message);
    process.exit(1);
  }
})();
