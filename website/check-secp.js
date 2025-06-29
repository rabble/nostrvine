const secp = require('@noble/secp256k1');

console.log('secp keys:', Object.keys(secp));
console.log('schnorr available:', !!secp.schnorr);
console.log('utils keys:', Object.keys(secp.utils));
console.log('etc keys:', Object.keys(secp.etc));

// Check version
try {
    console.log('package version:', require('@noble/secp256k1/package.json').version);
} catch (e) {
    console.log('could not get version');
}