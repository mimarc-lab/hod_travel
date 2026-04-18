import 'package:latlong2/latlong.dart' show LatLng;

/// Resolves place or city name strings to geographic [LatLng] coordinates.
///
/// Resolution order:
///   1. Exact key match against the luxury-destination database
///   2. Input string contains a known city name ("Aman Kyoto" → Kyoto)
///   3. Known city name contains the input ("Bali" → "Bali / Seminyak / …")
///   4. Returns null — item is unlocated; shown in the side panel only
///
/// A full geocoding integration (Nominatim, Mapbox Geocoding, etc.) can
/// replace or extend this in a future phase without changing the service API.
abstract class TripLocationService {
  // ── Static luxury-destination database ────────────────────────────────────

  static const Map<String, LatLng> _cities = {
    // ── International airports / transport hubs ──────────────────────────────
    // Japan
    'Narita':                LatLng(35.7648, 140.3864),
    'Narita Airport':        LatLng(35.7648, 140.3864),
    'NRT':                   LatLng(35.7648, 140.3864),
    'Haneda':                LatLng(35.5494, 139.7798),
    'Haneda Airport':        LatLng(35.5494, 139.7798),
    'HND':                   LatLng(35.5494, 139.7798),
    'Kansai Airport':        LatLng(34.4272, 135.2440),
    'KIX':                   LatLng(34.4272, 135.2440),
    'Itami Airport':         LatLng(34.7855, 135.4382),
    'NGO':                   LatLng(34.8584, 136.8054),
    // South-East Asia
    'Suvarnabhumi':          LatLng(13.6900, 100.7501),
    'Suvarnabhumi Airport':  LatLng(13.6900, 100.7501),
    'BKK':                   LatLng(13.6900, 100.7501),
    'Don Mueang':            LatLng(13.9132, 100.6069),
    'DMK':                   LatLng(13.9132, 100.6069),
    'Changi':                LatLng(1.3644,  103.9915),
    'Changi Airport':        LatLng(1.3644,  103.9915),
    'SIN':                   LatLng(1.3644,  103.9915),
    'Ngurah Rai':            LatLng(-8.7482, 115.1672),
    'Bali Airport':          LatLng(-8.7482, 115.1672),
    'DPS':                   LatLng(-8.7482, 115.1672),
    'Phuket Airport':        LatLng(8.1132,  98.3167),
    'HKT':                   LatLng(8.1132,  98.3167),
    'Samui Airport':         LatLng(9.5478,  100.0622),
    'USM':                   LatLng(9.5478,  100.0622),
    'Chiang Mai Airport':    LatLng(18.7668, 98.9627),
    'CNX':                   LatLng(18.7668, 98.9627),
    'KLIA':                  LatLng(2.7456,  101.7099),
    'KUL':                   LatLng(2.7456,  101.7099),
    'Nguyen Tat Thanh':      LatLng(10.8188, 106.6520),
    'SGN':                   LatLng(10.8188, 106.6520),
    'Noi Bai':               LatLng(21.2212, 105.8072),
    'HAN':                   LatLng(21.2212, 105.8072),
    // Indian subcontinent
    'Indira Gandhi':         LatLng(28.5562, 77.1000),
    'DEL':                   LatLng(28.5562, 77.1000),
    'Chhatrapati Shivaji':   LatLng(19.0896, 72.8656),
    'BOM':                   LatLng(19.0896, 72.8656),
    'Velana':                LatLng(4.1912,  73.5290),
    'MLE':                   LatLng(4.1912,  73.5290),
    'Bandaranaike':          LatLng(7.1804,  79.8841),
    'CMB':                   LatLng(7.1804,  79.8841),
    // East Asia
    'HKIA':                  LatLng(22.3080, 113.9185),
    'Hong Kong Airport':     LatLng(22.3080, 113.9185),
    'HKG':                   LatLng(22.3080, 113.9185),
    'Pudong':                LatLng(31.1443, 121.8083),
    'PVG':                   LatLng(31.1443, 121.8083),
    'Hongqiao':              LatLng(31.1979, 121.3363),
    'SHA':                   LatLng(31.1979, 121.3363),
    'Incheon':               LatLng(37.4602, 126.4407),
    'ICN':                   LatLng(37.4602, 126.4407),
    // Oceania
    'Sydney Airport':        LatLng(-33.9399, 151.1753),
    'SYD':                   LatLng(-33.9399, 151.1753),
    'Melbourne Airport':     LatLng(-37.6690, 144.8410),
    'MEL':                   LatLng(-37.6690, 144.8410),
    // Middle East
    'DXB':                   LatLng(25.2532, 55.3657),
    'Dubai Airport':         LatLng(25.2532, 55.3657),
    'AUH':                   LatLng(24.4330, 54.6511),
    'Abu Dhabi Airport':     LatLng(24.4330, 54.6511),
    'DOH':                   LatLng(25.2609, 51.6138),
    'Hamad Airport':         LatLng(25.2609, 51.6138),
    // Europe
    'CDG':                   LatLng(49.0097, 2.5479),
    'Charles de Gaulle':     LatLng(49.0097, 2.5479),
    'Orly':                  LatLng(48.7233, 2.3795),
    'ORY':                   LatLng(48.7233, 2.3795),
    'Nice Airport':          LatLng(43.6653, 7.2150),
    'NCE':                   LatLng(43.6653, 7.2150),
    'Heathrow':              LatLng(51.4700, -0.4543),
    'LHR':                   LatLng(51.4700, -0.4543),
    'Gatwick':               LatLng(51.1481, -0.1903),
    'LGW':                   LatLng(51.1481, -0.1903),
    'Edinburgh Airport':     LatLng(55.9500, -3.3725),
    'EDI':                   LatLng(55.9500, -3.3725),
    'El Prat':               LatLng(41.2974, 2.0785),
    'BCN':                   LatLng(41.2974, 2.0785),
    'Barajas':               LatLng(40.4719, -3.5626),
    'MAD':                   LatLng(40.4719, -3.5626),
    'Fiumicino':             LatLng(41.8003, 12.2389),
    'FCO':                   LatLng(41.8003, 12.2389),
    'Malpensa':              LatLng(45.6301, 8.7231),
    'MXP':                   LatLng(45.6301, 8.7231),
    'Marco Polo':            LatLng(45.5053, 12.3519),
    'VCE':                   LatLng(45.5053, 12.3519),
    'Amerigo Vespucci':      LatLng(43.8100, 11.2051),
    'FLR':                   LatLng(43.8100, 11.2051),
    'AMS':                   LatLng(52.3105, 4.7683),
    'Schiphol':              LatLng(52.3105, 4.7683),
    'Zurich Airport':        LatLng(47.4647, 8.5492),
    'ZRH':                   LatLng(47.4647, 8.5492),
    'Vienna Airport':        LatLng(48.1103, 16.5697),
    'VIE':                   LatLng(48.1103, 16.5697),
    'Athens Airport':        LatLng(37.9364, 23.9445),
    'ATH':                   LatLng(37.9364, 23.9445),
    'Istanbul Airport':      LatLng(41.2753, 28.7519),
    'IST':                   LatLng(41.2753, 28.7519),
    'Sabiha':                LatLng(40.8986, 29.3092),
    'SAW':                   LatLng(40.8986, 29.3092),
    // Americas
    'JFK':                   LatLng(40.6413, -73.7781),
    'John F Kennedy':        LatLng(40.6413, -73.7781),
    'Newark':                LatLng(40.6895, -74.1745),
    'EWR':                   LatLng(40.6895, -74.1745),
    'LAX':                   LatLng(33.9425, -118.4081),
    'Los Angeles Airport':   LatLng(33.9425, -118.4081),
    'SFO':                   LatLng(37.6213, -122.3790),
    'San Francisco Airport': LatLng(37.6213, -122.3790),
    'MIA':                   LatLng(25.7959, -80.2870),
    'Miami Airport':         LatLng(25.7959, -80.2870),
    'O\'Hare':               LatLng(41.9742, -87.9073),
    'ORD':                   LatLng(41.9742, -87.9073),
    'IAH':                   LatLng(29.9902, -95.3368),
    'George Bush':           LatLng(29.9902, -95.3368),
    'Houston Airport':       LatLng(29.9902, -95.3368),
    'HOU':                   LatLng(29.6454, -95.2789),
    'Hobby Airport':         LatLng(29.6454, -95.2789),
    // Africa
    'OR Tambo':              LatLng(-26.1392, 28.2460),
    'JNB':                   LatLng(-26.1392, 28.2460),
    'Cape Town Airport':     LatLng(-33.9715, 18.6021),
    'CPT':                   LatLng(-33.9715, 18.6021),
    'JKIA':                  LatLng(-1.3192,  36.9275),
    'NBO':                   LatLng(-1.3192,  36.9275),

    // ── City destinations ────────────────────────────────────────────────────
    // Japan
    'Tokyo':          LatLng(35.6762, 139.6503),
    'Kyoto':          LatLng(35.0116, 135.7681),
    'Osaka':          LatLng(34.6937, 135.5023),
    'Nara':           LatLng(34.6851, 135.8049),
    'Hiroshima':      LatLng(34.3853, 132.4553),
    'Hakone':         LatLng(35.2333, 139.1067),
    'Nikko':          LatLng(36.7198, 139.6983),
    'Sapporo':        LatLng(43.0618, 141.3545),
    'Kanazawa':       LatLng(36.5613, 136.6562),
    'Okinawa':        LatLng(26.2124, 127.6809),
    // South-East Asia
    'Bali':           LatLng(-8.4095, 115.1889),
    'Ubud':           LatLng(-8.5069, 115.2625),
    'Seminyak':       LatLng(-8.6881, 115.1565),
    'Canggu':         LatLng(-8.6500, 115.1373),
    'Nusa Penida':    LatLng(-8.7280, 115.5435),
    'Lombok':         LatLng(-8.6500, 116.3241),
    'Bangkok':        LatLng(13.7563, 100.5018),
    'Chiang Mai':     LatLng(18.7883, 98.9853),
    'Chiang Rai':     LatLng(19.9071, 99.8307),
    'Phuket':         LatLng(7.8804, 98.3923),
    'Koh Samui':      LatLng(9.5120, 100.0136),
    'Koh Lanta':      LatLng(7.5167, 99.0833),
    'Singapore':      LatLng(1.3521, 103.8198),
    'Kuala Lumpur':   LatLng(3.1390, 101.6869),
    'Langkawi':       LatLng(6.3500, 99.8000),
    'Penang':         LatLng(5.4141, 100.3288),
    'Hanoi':          LatLng(21.0278, 105.8342),
    'Ho Chi Minh':    LatLng(10.8231, 106.6297),
    'Hoi An':         LatLng(15.8794, 108.3350),
    'Da Nang':        LatLng(16.0544, 108.2022),
    'Ha Long':        LatLng(20.9101, 107.1839),
    'Siem Reap':      LatLng(13.3671, 103.8448),
    'Phnom Penh':     LatLng(11.5564, 104.9282),
    'Yangon':         LatLng(16.8661, 96.1951),
    'Mandalay':       LatLng(21.9588, 96.0891),
    'Bagan':          LatLng(21.1717, 94.8585),
    // Indian subcontinent
    'Maldives':       LatLng(3.2028, 73.2207),
    'Malé':           LatLng(4.1755, 73.5093),
    'Sri Lanka':      LatLng(7.8731, 80.7718),
    'Colombo':        LatLng(6.9271, 79.8612),
    'Galle':          LatLng(6.0535, 80.2210),
    'Sigiriya':       LatLng(7.9570, 80.7603),
    'Mumbai':         LatLng(19.0760, 72.8777),
    'Delhi':          LatLng(28.6139, 77.2090),
    'Jaipur':         LatLng(26.9124, 75.7873),
    'Udaipur':        LatLng(24.5854, 73.7125),
    'Agra':           LatLng(27.1767, 78.0081),
    'Jodhpur':        LatLng(26.2389, 73.0243),
    'Ranthambore':    LatLng(26.0171, 76.5025),
    // East Asia
    'Hong Kong':      LatLng(22.3193, 114.1694),
    'Macau':          LatLng(22.1987, 113.5439),
    'Shanghai':       LatLng(31.2304, 121.4737),
    'Beijing':        LatLng(39.9042, 116.4074),
    'Chengdu':        LatLng(30.5728, 104.0668),
    'Guilin':         LatLng(25.2736, 110.2908),
    'Zhangjiajie':    LatLng(29.1170, 110.4790),
    'Seoul':          LatLng(37.5665, 126.9780),
    'Busan':          LatLng(35.1796, 129.0756),
    'Jeju':           LatLng(33.4996, 126.5312),
    // Oceania
    'Sydney':         LatLng(-33.8688, 151.2093),
    'Melbourne':      LatLng(-37.8136, 144.9631),
    'Brisbane':       LatLng(-27.4705, 153.0260),
    'Cairns':         LatLng(-16.9186, 145.7781),
    'Whitsundays':    LatLng(-20.2800, 148.9800),
    'Gold Coast':     LatLng(-28.0167, 153.4000),
    'Auckland':       LatLng(-36.8485, 174.7633),
    'Queenstown':     LatLng(-45.0312, 168.6626),
    'Rotorua':        LatLng(-38.1368, 176.2497),
    'Fiji':           LatLng(-17.7134, 178.0650),
    // Middle East
    'Dubai':          LatLng(25.2048, 55.2708),
    'Abu Dhabi':      LatLng(24.4539, 54.3773),
    'Doha':           LatLng(25.2854, 51.5310),
    'Muscat':         LatLng(23.5880, 58.3829),
    'Petra':          LatLng(30.3285, 35.4444),
    'Amman':          LatLng(31.9539, 35.9106),
    'Jerusalem':      LatLng(31.7683, 35.2137),
    // Africa
    'Marrakech':      LatLng(31.6295, -7.9811),
    'Fez':            LatLng(34.0181, -5.0078),
    'Casablanca':     LatLng(33.5731, -7.5898),
    'Cairo':          LatLng(30.0444, 31.2357),
    'Luxor':          LatLng(25.6872, 32.6396),
    'Cape Town':      LatLng(-33.9249, 18.4241),
    'Johannesburg':   LatLng(-26.2041, 28.0473),
    'Nairobi':        LatLng(-1.2921, 36.8219),
    'Zanzibar':       LatLng(-6.1659, 39.1999),
    'Serengeti':      LatLng(-2.3333, 34.8333),
    'Masai Mara':     LatLng(-1.5000, 35.1500),
    'Victoria Falls': LatLng(-17.9243, 25.8572),
    'Kruger':         LatLng(-23.9884, 31.5550),
    'Seychelles':     LatLng(-4.6796, 55.4920),
    'Mauritius':      LatLng(-20.3484, 57.5522),
    'Réunion':        LatLng(-21.1151, 55.5364),
    // Europe — France
    'Paris':          LatLng(48.8566, 2.3522),
    'Nice':           LatLng(43.7102, 7.2620),
    'Cannes':         LatLng(43.5528, 7.0174),
    'Saint-Tropez':   LatLng(43.2677, 6.6407),
    'Monaco':         LatLng(43.7384, 7.4246),
    'Bordeaux':       LatLng(44.8378, -0.5792),
    'Lyon':           LatLng(45.7640, 4.8357),
    'Provence':       LatLng(43.9352, 5.7240),
    'Champagne':      LatLng(49.2583, 4.0317),
    // Europe — Italy
    'Rome':           LatLng(41.9028, 12.4964),
    'Florence':       LatLng(43.7696, 11.2558),
    'Venice':         LatLng(45.4408, 12.3155),
    'Milan':          LatLng(45.4642, 9.1900),
    'Amalfi':         LatLng(40.6340, 14.6027),
    'Positano':       LatLng(40.6282, 14.4850),
    'Capri':          LatLng(40.5531, 14.2427),
    'Ravello':        LatLng(40.6466, 14.6125),
    'Tuscany':        LatLng(43.7711, 11.2486),
    'Portofino':      LatLng(44.3040, 9.2096),
    'Taormina':       LatLng(37.8519, 15.2835),
    'Sicily':         LatLng(37.5999, 14.0154),
    // Europe — UK + Ireland
    'London':         LatLng(51.5074, -0.1278),
    'Edinburgh':      LatLng(55.9533, -3.1883),
    'Glasgow':        LatLng(55.8642, -4.2518),
    'Dublin':         LatLng(53.3498, -6.2603),
    'Bath':           LatLng(51.3811, -2.3590),
    'Cotswolds':      LatLng(51.8330, -1.8433),
    // Europe — Iberia
    'Barcelona':      LatLng(41.3851, 2.1734),
    'Madrid':         LatLng(40.4168, -3.7038),
    'Seville':        LatLng(37.3891, -5.9845),
    'Granada':        LatLng(37.1773, -3.5986),
    'Marbella':       LatLng(36.5100, -4.8824),
    'Lisbon':         LatLng(38.7169, -9.1399),
    'Porto':          LatLng(41.1579, -8.6291),
    'Algarve':        LatLng(37.0179, -7.9309),
    'Douro':          LatLng(41.1663, -7.6660),
    // Europe — Greece
    'Athens':         LatLng(37.9838, 23.7275),
    'Santorini':      LatLng(36.3932, 25.4615),
    'Mykonos':        LatLng(37.4415, 25.3274),
    'Rhodes':         LatLng(36.4341, 28.2176),
    'Corfu':          LatLng(39.6243, 19.9217),
    'Crete':          LatLng(35.2401, 24.8093),
    // Europe — Adriatic
    'Dubrovnik':      LatLng(42.6507, 18.0944),
    'Split':          LatLng(43.5081, 16.4402),
    'Hvar':           LatLng(43.1724, 16.4413),
    'Kotor':          LatLng(42.4247, 18.7712),
    // Europe — Central
    'Vienna':         LatLng(48.2082, 16.3738),
    'Salzburg':       LatLng(47.8095, 13.0550),
    'Prague':         LatLng(50.0755, 14.4378),
    'Budapest':       LatLng(47.4979, 19.0402),
    // Europe — Switzerland
    'Zürich':         LatLng(47.3769, 8.5417),
    'Geneva':         LatLng(46.2044, 6.1432),
    'Zermatt':        LatLng(46.0207, 7.7491),
    'St. Moritz':     LatLng(46.4975, 9.8368),
    'Lucerne':        LatLng(47.0502, 8.3093),
    'Interlaken':     LatLng(46.6863, 7.8632),
    // Europe — Scandinavia
    'Amsterdam':      LatLng(52.3676, 4.9041),
    'Copenhagen':     LatLng(55.6761, 12.5683),
    'Stockholm':      LatLng(59.3293, 18.0686),
    'Oslo':           LatLng(59.9139, 10.7522),
    'Bergen':         LatLng(60.3913, 5.3221),
    'Reykjavik':      LatLng(64.1355, -21.8954),
    // Turkey
    'Istanbul':       LatLng(41.0082, 28.9784),
    'Cappadocia':     LatLng(38.6431, 34.8289),
    'Bodrum':         LatLng(37.0344, 27.4305),
    // Americas
    'New York':       LatLng(40.7128, -74.0060),
    'Los Angeles':    LatLng(34.0522, -118.2437),
    'San Francisco':  LatLng(37.7749, -122.4194),
    'Miami':          LatLng(25.7617, -80.1918),
    'Chicago':        LatLng(41.8781, -87.6298),
    'Houston':        LatLng(29.7604, -95.3698),
    'Napa':           LatLng(38.2975, -122.2869),
    'Hawaii':         LatLng(20.7984, -156.3319),
    'Maui':           LatLng(20.7984, -156.3319),
    'Big Island':     LatLng(19.5429, -155.6659),
    'Mexico City':    LatLng(19.4326, -99.1332),
    'Oaxaca':         LatLng(17.0600, -96.7220),
    'Cancún':         LatLng(21.1619, -86.8515),
    'Tulum':          LatLng(20.2114, -87.4654),
    'Los Cabos':      LatLng(22.8905, -109.9167),
    'Buenos Aires':   LatLng(-34.6037, -58.3816),
    'Patagonia':      LatLng(-51.6230, -72.7153),
    'Lima':           LatLng(-12.0464, -77.0428),
    'Cusco':          LatLng(-13.5320, -71.9675),
    'Machu Picchu':   LatLng(-13.1631, -72.5450),
    'Sacred Valley':  LatLng(-13.3167, -72.1167),
    'Rio de Janeiro': LatLng(-22.9068, -43.1729),
    'Galápagos':      LatLng(-0.9538, -90.9656),
    'Cartagena':      LatLng(10.3910, -75.4794),
    'Antigua':        LatLng(17.1274, -61.8468),
    'Barbados':       LatLng(13.1939, -59.5432),
    'St Barts':       LatLng(17.9000, -62.8333),
    'Turks and Caicos': LatLng(21.6940, -71.7979),
    'Jamaica':        LatLng(18.1096, -77.2975),

    // ── Venue-level entries (luxury hotels, districts, landmarks) ────────────
    // These longer keys beat generic city names in Pass 2 once we sort by
    // key-length descending, giving accurate sub-city pin placement.

    // Tokyo — luxury hotels
    'Mandarin Oriental Tokyo':        LatLng(35.6854, 139.7749),
    'Park Hyatt Tokyo':               LatLng(35.6862, 139.6910),
    'The Peninsula Tokyo':            LatLng(35.6742, 139.7576),
    'Peninsula Tokyo':                LatLng(35.6742, 139.7576),
    'Aman Tokyo':                     LatLng(35.6852, 139.7636),
    'Four Seasons Tokyo Otemachi':    LatLng(35.6884, 139.7637),
    'Four Seasons Tokyo Marunouchi':  LatLng(35.6798, 139.7674),
    'Ritz-Carlton Tokyo':             LatLng(35.6603, 139.7305),
    'Conrad Tokyo':                   LatLng(35.6620, 139.7580),
    'Grand Hyatt Tokyo':              LatLng(35.6600, 139.7314),
    'Andaz Tokyo':                    LatLng(35.6910, 139.7668),
    'Palace Hotel Tokyo':             LatLng(35.6868, 139.7572),
    'Imperial Hotel Tokyo':           LatLng(35.6735, 139.7591),
    'Hotel Okura Tokyo':              LatLng(35.6694, 139.7458),
    'Hotel New Otani Tokyo':          LatLng(35.6851, 139.7376),
    'Keio Plaza Hotel Tokyo':         LatLng(35.6934, 139.6927),
    'Tokyo Marriott':                 LatLng(35.6226, 139.7261),
    'Cerulean Tower':                 LatLng(35.6539, 139.6980),
    'Hyatt Regency Tokyo':            LatLng(35.6944, 139.6929),

    // Tokyo — districts / neighbourhoods (match full addresses containing these)
    'Nihonbashi Muromachi':           LatLng(35.6854, 139.7749),
    'Nihonbashi':                     LatLng(35.6836, 139.7740),
    'Nishishinjuku':                  LatLng(35.6862, 139.6910), // no-separator form used in real addresses → Park Hyatt area
    'Nishi-Shinjuku':                 LatLng(35.6886, 139.6908),
    'Nishi Shinjuku':                 LatLng(35.6886, 139.6908),
    'Shinjuku':                       LatLng(35.6938, 139.7034),
    'Roppongi Hills':                 LatLng(35.6600, 139.7296),
    'Roppongi':                       LatLng(35.6627, 139.7319),
    'Tokyo Midtown':                  LatLng(35.6650, 139.7307),
    'Ginza':                          LatLng(35.6717, 139.7650),
    'Marunouchi':                     LatLng(35.6817, 139.7639),
    'Otemachi':                       LatLng(35.6864, 139.7624),
    'Yurakucho':                      LatLng(35.6747, 139.7626),
    'Hibiya':                         LatLng(35.6724, 139.7594),
    'Akasaka':                        LatLng(35.6751, 139.7391),
    'Shiodome':                       LatLng(35.6594, 139.7595),
    'Toranomon':                      LatLng(35.6671, 139.7493),
    'Shibuya':                        LatLng(35.6580, 139.7016),
    'Harajuku':                       LatLng(35.6702, 139.7026),
    'Daikanyama':                     LatLng(35.6498, 139.7030),
    'Nakameguro':                     LatLng(35.6440, 139.6990),
    'Ebisu':                          LatLng(35.6475, 139.7101),
    'Minami-Aoyama':                  LatLng(35.6648, 139.7167),
    'Aoyama':                         LatLng(35.6697, 139.7153),
    'Asakusa':                        LatLng(35.7148, 139.7967),
    'Ueno':                           LatLng(35.7142, 139.7769),
    'Akihabara':                      LatLng(35.7021, 139.7745),
    'Odaiba':                         LatLng(35.6294, 139.7759),
    'Shinagawa':                      LatLng(35.6284, 139.7387),
    'Azabu':                          LatLng(35.6550, 139.7278),
    'Minato':                         LatLng(35.6498, 139.7512),
    'Chuo':                           LatLng(35.6687, 139.7718),

    // Tokyo — landmarks
    'Imperial Palace':                LatLng(35.6852, 139.7528),
    'Tokyo Tower':                    LatLng(35.6586, 139.7454),
    'Tokyo Skytree':                  LatLng(35.7101, 139.8107),
    'Skytree':                        LatLng(35.7101, 139.8107),
    'Tsukiji Market':                 LatLng(35.6654, 139.7707),
    'Toyosu Market':                  LatLng(35.6490, 139.7840),
    'Meiji Shrine':                   LatLng(35.6763, 139.6993),
    'Sensoji':                        LatLng(35.7148, 139.7967),
    'Senso-ji':                       LatLng(35.7148, 139.7967),
    'Shinjuku Gyoen':                 LatLng(35.6852, 139.7104),
    'Teamlab':                        LatLng(35.6248, 139.7761),
    'teamLab':                        LatLng(35.6248, 139.7761),
    'Sumo Hall':                      LatLng(35.7022, 139.7938),
    'Kabukiza':                       LatLng(35.6695, 139.7657),
    'Nakagin':                        LatLng(35.6696, 139.7633),

    // Bali — luxury hotels & areas
    'Four Seasons Bali Sayan':        LatLng(-8.4882, 115.2500),
    'Four Seasons Bali Jimbaran':     LatLng(-8.7887, 115.1656),
    'Aman Bali':                      LatLng(-8.4882, 115.2500),
    'Amandari':                       LatLng(-8.5142, 115.2536),
    'Amanusa':                        LatLng(-8.7970, 115.1568),
    'Como Shambhala':                 LatLng(-8.4883, 115.2582),
    'Alila Ubud':                     LatLng(-8.5273, 115.2617),
    'Alila Villas Uluwatu':           LatLng(-8.8268, 115.0897),
    'Bulgari Resort Bali':            LatLng(-8.7974, 115.1568),
    'Bvlgari Resort Bali':            LatLng(-8.7974, 115.1568),
    'Jimbaran':                       LatLng(-8.7887, 115.1656),
    'Uluwatu':                        LatLng(-8.8298, 115.0849),
    'Nusa Dua':                       LatLng(-8.8001, 115.2310),
    'Kuta':                           LatLng(-8.7214, 115.1684),
    'Legian':                         LatLng(-8.7022, 115.1700),

    // Bangkok — luxury hotels & areas
    'Mandarin Oriental Bangkok':      LatLng(13.7221, 100.5143),
    'Peninsula Bangkok':              LatLng(13.7178, 100.5114),
    'Capella Bangkok':                LatLng(13.7178, 100.5133),
    'The Peninsula Bangkok':          LatLng(13.7178, 100.5114),
    'Four Seasons Bangkok':           LatLng(13.7168, 100.5097),
    'Rosewood Bangkok':               LatLng(13.7438, 100.5489),
    'Park Hyatt Bangkok':             LatLng(13.7438, 100.5489),
    'Sukhumvit':                      LatLng(13.7388, 100.5601),
    'Silom':                          LatLng(13.7247, 100.5268),
    'Chao Phraya':                    LatLng(13.7221, 100.5143),
    'Sathorn':                        LatLng(13.7213, 100.5299),
    'Wat Pho':                        LatLng(13.7463, 100.4928),
    'Wat Arun':                       LatLng(13.7439, 100.4888),
    'Grand Palace':                   LatLng(13.7500, 100.4913),

    // Singapore — luxury hotels & areas
    'Raffles Hotel Singapore':        LatLng(1.2948,  103.8524),
    'Marina Bay Sands':               LatLng(1.2834,  103.8607),
    'Capella Singapore':              LatLng(1.2479,  103.8272),
    'Mandarin Oriental Singapore':    LatLng(1.2836,  103.8598),
    'Fullerton Hotel':                LatLng(1.2863,  103.8534),
    'Marina Bay':                     LatLng(1.2834,  103.8607),
    'Orchard Road':                   LatLng(1.3046,  103.8318),
    'Clarke Quay':                    LatLng(1.2894,  103.8464),
    'Sentosa':                        LatLng(1.2494,  103.8303),
    'Gardens by the Bay':             LatLng(1.2816,  103.8636),

    // Paris — luxury hotels & areas
    'Hotel Ritz Paris':               LatLng(48.8683, 2.3294),
    'Le Bristol Paris':               LatLng(48.8739, 2.3119),
    'Hotel de Crillon':               LatLng(48.8666, 2.3207),
    'Four Seasons Hotel George V':    LatLng(48.8735, 2.3012),
    'George V Paris':                 LatLng(48.8735, 2.3012),
    'Mandarin Oriental Paris':        LatLng(48.8658, 2.3317),
    'Plaza Athénée':                  LatLng(48.8659, 2.3038),
    'Champs-Élysées':                 LatLng(48.8698, 2.3078),
    'Saint-Germain':                  LatLng(48.8534, 2.3348),
    'Le Marais':                      LatLng(48.8568, 2.3544),
    'Louvre':                         LatLng(48.8606, 2.3376),
    'Eiffel Tower':                   LatLng(48.8584, 2.2945),
    'Versailles':                     LatLng(48.8049, 2.1204),
    'Montmartre':                     LatLng(48.8867, 2.3431),

    // Dubai — luxury hotels & areas
    'Burj Al Arab':                   LatLng(25.1412, 55.1853),
    'Atlantis The Palm':              LatLng(25.1300, 55.1170),
    'One&Only The Palm':              LatLng(25.1296, 55.1282),
    'Jumeirah Beach Hotel':           LatLng(25.1444, 55.1911),
    'Address Downtown Dubai':         LatLng(25.1915, 55.2753),
    'Four Seasons Dubai':             LatLng(25.1975, 55.2744),
    'DIFC':                           LatLng(25.2131, 55.2796),
    'Downtown Dubai':                 LatLng(25.1972, 55.2744),
    'Dubai Marina':                   LatLng(25.0753, 55.1339),
    'Palm Jumeirah':                  LatLng(25.1124, 55.1390),
    'Jumeirah':                       LatLng(25.2048, 55.2708),
    'Burj Khalifa':                   LatLng(25.1972, 55.2744),
    'Dubai Mall':                     LatLng(25.1972, 55.2796),

    // Maldives — key resorts
    'Soneva Fushi':                   LatLng(5.1051,  72.9964),
    'Soneva Jani':                    LatLng(5.5944,  73.4010),
    'Cheval Blanc Randheli':          LatLng(5.5929,  73.4012),
    'Six Senses Laamu':               LatLng(1.8458,  73.5000),
    'Gili Lankanfushi':               LatLng(4.2842,  73.4804),
    'Velaa Private Island':           LatLng(5.5944,  73.4010),
    'North Malé Atoll':               LatLng(4.2842,  73.4804),
    'South Malé Atoll':               LatLng(3.5000,  73.3000),
  };

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns [LatLng] for [location] (item-level) or [cityHint] (day city).
  /// Returns null when neither can be resolved.
  static LatLng? resolve(String? location, String? cityHint) {
    if (location != null && location.isNotEmpty) {
      final fromLocation = _match(location);
      if (fromLocation != null) return fromLocation;
    }
    if (cityHint != null && cityHint.isNotEmpty) {
      return _match(cityHint);
    }
    return null;
  }

  /// For transport / logistics items: tries to extract an origin and
  /// destination from the item [title] and return their coordinates.
  ///
  /// Patterns recognised (case-insensitive):
  ///   "from [A] to [B]"  →  resolves A and B separately
  ///   "[A] to [B]"       →  resolves A and B; generic verbs (Transfer, Drive …)
  ///                         are treated as the origin city
  ///
  /// [cityHint] is used as a fallback when one side cannot be resolved.
  /// Returns null when fewer than two distinct coordinates can be found.
  static ({LatLng from, LatLng to})? parseTransportRoute(
      String title, String? cityHint) {
    final cityCoords =
        (cityHint != null && cityHint.isNotEmpty) ? _match(cityHint) : null;

    // ── Pattern 1: "from [A] to [B]" ─────────────────────────────────────────
    final fromToRe =
        RegExp(r'\bfrom\s+(.+?)\s+to\s+(.+)', caseSensitive: false);
    final m1 = fromToRe.firstMatch(title);
    if (m1 != null) {
      final aCoords = _match(m1.group(1)!.trim()) ?? cityCoords;
      final bCoords = _match(m1.group(2)!.trim()) ?? cityCoords;
      if (aCoords != null && bCoords != null) {
        return (from: aCoords, to: bCoords);
      }
    }

    // ── Pattern 2: "[A] to [B]" (no explicit "from") ─────────────────────────
    // Skip single-word generic transport verbs that are not place names.
    const transportVerbs = {
      'transfer', 'drive', 'flight', 'fly', 'taxi', 'bus', 'train',
      'shuttle', 'pickup', 'pick-up', 'drop', 'drop-off', 'ride',
      'transport', 'departure', 'arrival', 'depart', 'arrive',
    };
    final toRe = RegExp(r'^(.+?)\s+to\s+(.+)$', caseSensitive: false);
    final m2 = toRe.firstMatch(title);
    if (m2 != null) {
      final aStr = m2.group(1)!.trim();
      final bStr = m2.group(2)!.trim();
      final aIsVerb = transportVerbs.contains(aStr.toLowerCase());
      final aCoords = aIsVerb ? cityCoords : (_match(aStr) ?? cityCoords);
      final bCoords = _match(bStr) ?? cityCoords;
      if (aCoords != null && bCoords != null) {
        return (from: aCoords, to: bCoords);
      }
    }

    return null;
  }

  // ── Private ────────────────────────────────────────────────────────────────

  /// Entries sorted longest-key-first so specific venue names
  /// ("Mandarin Oriental Tokyo", 24 chars) are tested before generic city
  /// names ("Tokyo", 5 chars) in Pass 2.  Computed once at class load time.
  static final List<MapEntry<String, LatLng>> _sortedEntries =
      _cities.entries.toList()
        ..sort((a, b) => b.key.length.compareTo(a.key.length));

  static LatLng? _match(String input) {
    final q = input.trim().toLowerCase();
    if (q.isEmpty) return null;

    // Pass 1 — exact key match
    for (final entry in _cities.entries) {
      if (entry.key.toLowerCase() == q) return entry.value;
    }

    // Pass 2 — input contains a location name.
    // Uses _sortedEntries (longest key first) so specific venue/district names
    // beat generic city names.  Short keys (≤ 4 chars: IATA codes like JFK,
    // VIE, CDG) require a word-boundary token match so they don't fire inside
    // common words ("vie" in "view", "ord" in "order", etc.).
    for (final entry in _sortedEntries) {
      final key = entry.key.toLowerCase();
      if (key.length <= 4) {
        if (RegExp(r'(?:^|[\s,\-/])' + RegExp.escape(key) + r'(?:$|[\s,\-/])')
            .hasMatch(q)) {
          return entry.value;
        }
      } else {
        if (q.contains(key)) return entry.value;
      }
    }

    // Pass 3 — city/location name contains the input (e.g. "bali" ↔ "Bali")
    for (final entry in _cities.entries) {
      if (entry.key.toLowerCase().contains(q)) return entry.value;
    }
    return null;
  }
}
