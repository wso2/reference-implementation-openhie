"""
Sri Lanka Patient Generator — realistic synthetic population for CR bulk DB insert.

Population model:
  - Ethnicity: Sinhala 75 %, Tamil 15 %, Muslim 10 %
  - Names: gender-specific per ethnicity (no cross-ethnic mixing)
    Pool sizes: ~120 given names per gender per ethnicity, ~100 family names per ethnicity
    → ~12,000 given×family combinations per ethnicity group
    → with 25,000+ possible DOBs, false dedup collision rate stays negligible at 1 M patients
  - Age: triangular distribution, mode 33 y, range 0–82 y (2024 Sri Lanka median)
  - NIC: old format (YYDDDNNNV/X) for births before 2000,
          new format (YYYYDDDNNNC) for 2000+; females add 500 to DDD
  - Cities: population-weighted across all 23 districts
  - Hospital: 70 % nearest provincial hospital, 30 % random
  - Given names: 30 % chance of two given names
  - Extensions: mothersMaidenName on 60 % of records
  - maritalStatus on adults (18 +)

Install:  pip install (no extra deps — stdlib only)
Run:      python cr-core/scripts/generate_lk_patients.py [--count N] [--output PATH]
Output:   ./output/pdqm_patients.ndjson  (one JSON Patient per line)
"""

import copy
import json
import os
import random
from datetime import date, timedelta

# ─── CONFIG ──────────────────────────────────────────────────────────────────
TOTAL_BASE  = 85_000
DUP_RATE    = 0.15
OUTPUT_FILE = "./output/pdqm_patients.ndjson"
LOG_EVERY   = 10_000
TODAY       = date(2024, 1, 1)
# ─────────────────────────────────────────────────────────────────────────────

# ── Name pools ────────────────────────────────────────────────────────────────
# Sizes: ~120 given per gender per ethnicity × ~100 family per ethnicity
# Sinhala group covers 750 K patients → ~12 K name combos × 25 K DOBs → very low collision rate

_NAMES = {
    "sinhala": {
        "male": [
            "Kamal","Nimal","Sunil","Ruwan","Asanka","Chamara","Dinesh","Tharaka",
            "Lasitha","Buddhika","Pradeep","Sampath","Roshan","Nuwan","Isuru",
            "Sachith","Gayan","Thilina","Lahiru","Kasun","Chaminda","Nalaka",
            "Dilshan","Prasanna","Udara","Janaka","Chathura","Saman","Dhanushka",
            "Charith","Supun","Madushanka","Harsha","Prabath","Tharindu","Gimhan",
            "Shehan","Malith","Shamal","Nalin","Dilan","Hasitha","Amila","Darshana",
            "Kapila","Pasindu","Ravindu","Kavinda","Yasiru","Randika","Sandun",
            "Dumindu","Chulanka","Rasitha","Thushara","Imesh","Sithum","Gehan",
            "Nilesh","Dammika","Priyantha","Bandula","Sanjeewa","Mahesh","Dilnath",
            "Harshana","Dasun","Pramod","Chamath","Vimukthi","Akila","Hirantha",
            "Samitha","Sehan","Lakshan","Rahal","Chanaka","Dimuth","Kavishka",
            "Isanka","Pasan","Thisara","Navod","Ruchira","Sagara","Waruna",
            "Bimantha","Amith","Vipula","Danushka","Rukshan","Madura","Sachira",
            "Chirantha","Asela","Nipuna","Maduranga","Kulasiri","Pathum","Ranmal",
            "Thisura","Hashan","Dushan","Hesara","Binath","Ruvinda","Achala",
            "Bhathiya","Chanuka","Uditha","Nishantha","Gihantha","Amaru","Shalinda",
            "Manjula","Keshan","Hiruna","Malinga","Muditha","Wasantha","Sameera",
        ],
        "female": [
            "Malani","Nimali","Dilhani","Chamari","Sandya","Rashmi","Kumari",
            "Thilini","Nadeesha","Anusha","Iresha","Samanthi","Kanchana",
            "Sewwandi","Hiruni","Ruwanthika","Amaya","Sachini","Nilmini","Shanika",
            "Dulani","Manisha","Upeksha","Kasuni","Achini","Dinusha","Hesitha",
            "Ishara","Nadeeka","Damayanthi","Pavithra","Chathurika","Nethmi",
            "Senuri","Piyumi","Thilanka","Harshani","Sashika","Niluka","Dulakshi",
            "Bimala","Rukshika","Vimukthi","Thisari","Naduni","Sehansa","Sandali",
            "Tharushika","Udari","Rashini","Hirantha","Nawodya","Vihangi","Amashika",
            "Lasandi","Hashini","Sulochana","Wasana","Pradeepa","Sunethra","Kamani",
            "Ruwani","Dilini","Rangi","Nelum","Kavindi","Thisuri","Saduni","Binara",
            "Yeheli","Amoda","Madushi","Sithara","Navoda","Hasini","Ruwanthi",
            "Dilrukshi","Pramila","Lihini","Naomi","Chamathka","Dewmini","Sumudu",
            "Tharaka","Inoka","Jayomi","Menaka","Renuka","Ayasha","Chandani",
            "Lasanthi","Nirosha","Tharushani","Harini","Sashini","Vindya","Maheshi",
            "Surangika","Sandamali","Bhagya","Gayathri","Shanudi","Nithushi",
            "Tarushi","Amali","Dilhara","Sathsarani","Tharushika","Imesha",
            "Pabasara","Oneli","Senali","Hirunika","Thilakshi","Vinodya",
        ],
        "family": [
            "Perera","Silva","Fernando","Jayasinghe","Wickramasinghe","Rajapaksa",
            "Dissanayake","Gunasekara","Herath","Bandara","Seneviratne",
            "Weerasinghe","Ranasinghe","Pathirana","Dharmawardena","Jayawardena",
            "Liyanage","Kumara","Gamage","Rathnayake","Nanayakkara","Senanayake",
            "Marasinghe","Peiris","Abeywickrama","Karunaratne","Gunawardena",
            "Samarasinghe","Wijesekara","Ekanayake","Hapuarachchi","Illangakoon",
            "Wimalasiri","Rajapaksha","Kodikara","Wickrama","Ariyarathne",
            "Pieris","Alwis","Senerath","Karunanayake","Subasinghe","Amarasekara",
            "Fonseka","Rodrigo","Wijewardena","Abeyrathne","Weerakkody",
            "Gunasinghe","Siriwardana","Kotelawala","Dasanayake","Palihawadana",
            "Munasinghe","Kumarasinghe","Ranatunga","Wijekoon","Tennekoon",
            "Jayathilaka","Athukorala","Wickremasinghe","Liyanaarachchi",
            "Godakanda","Samaranayake","Navaratne","Koswatta","Dissanayaka",
            "Siriwardhana","Thilakarathne","Wijayasundara","Rambukwella",
            "Rajapakshe","Weerawansa","Bandaranayake","Sirisena","Wijesinghe",
            "Jayasundara","Halangoda","Lansakara","Pathmaperuma","Rathnasiri",
            "Wijayaratne","Kosgoda","Gajanayake","Tennakoon","Bulathsinghala",
            "Madanayake","Kahaduwa","Ranaweera","Pathmasiri","Jayakodi",
            "Rajapakshe","Weerasekera","Nandadasa","Hettiarachchi","Wickramaratne",
            "Amarasinghe","Edirisinghe","Seneviratne","Kalansuriya","Chandrasekera",
        ],
    },

    "tamil": {
        "male": [
            "Arjun","Vijay","Kumar","Rajan","Selvam","Maran","Suresh","Prasath",
            "Balamurugan","Karthik","Arun","Muthu","Senthil","Rajesh","Vignesh",
            "Ganesh","Sathish","Praveen","Hariharan","Thevakumar","Sivakumar",
            "Jeyaraj","Nirmal","Yogesh","Pirathap","Suthakaran","Mathivanan",
            "Abilash","Anbuselvan","Arockiam","Balakrishnan","Chandran","Dhanraj",
            "Elavarasan","Govindaraj","Gunaseelan","Hari","Ilanchezhiyan",
            "Jayakumar","Kannan","Loganathan","Manikandan","Nagarajan","Pandian",
            "Ramesh","Santhanam","Tamilselvan","Udhayakumar","Vasanthakumar",
            "Yuvaraj","Anand","Balasubramanian","Chellapandian","Durai",
            "Ezhilan","Gowrisankar","Harisankar","Ilayaraja","Jothivel",
            "Kathiresan","Logesh","Manoharan","Natarajan","Palanivel","Ravi",
            "Saravanan","Thiagarajan","Umapathy","Venkatesh","Aarumugam",
            "Baskaran","Chelvan","Dhanapal","Elango","Gopal","Haribabu",
            "Ilangovan","Jeyakumar","Kalaichelvan","Lingam","Maharajan",
            "Nandakumar","Palaniswamy","Raghavan","Subramanian","Thirumaran",
            "Valavan","Vimalraj","Annamalai","Chidambaram","Dhanasekaran",
        ],
        "female": [
            "Priya","Kavitha","Meena","Lakshmi","Anitha","Geetha","Nithya","Divya",
            "Deepa","Revathi","Saranya","Padmini","Vasantha","Thilaga","Kamala",
            "Suganya","Niroshini","Parameshwari","Jeyanthi","Tharshini","Yalini",
            "Sathya","Karthiga","Shakthika","Uthaya","Banusha","Aaruvi","Abinaya",
            "Akalya","Ambiga","Bavithra","Chandra","Dharani","Eswari","Gayathri",
            "Hemamalini","Indumathi","Jayalakshmi","Kalavathy","Lavanya",
            "Maheswari","Nandhini","Oviya","Ponmalar","Rajeswari","Sangeetha",
            "Thenmalar","Uma","Vasuki","Yamuna","Abirami","Bharathi","Chithra",
            "Dharshika","Elavarasi","Gomathi","Hemalatha","Ilampirai","Janaki",
            "Kokila","Latha","Maalathi","Nalini","Parvathi","Radha","Sakthi",
            "Tamilarasi","Usha","Valli","Amutha","Bhuvaneswari","Chellamma",
            "Deivanai","Ezhilarasi","Gowri","Hemavathy","Ilakiya","Karunambal",
            "Kalaimagal","Mahalakshmi","Nirmala","Parimala","Rani","Sivakami",
            "Thamarai","Vimala","Annapoorani","Bavani","Chithira","Durga",
        ],
        "family": [
            "Navaratnam","Balasundaram","Ratnasingham","Krishnarajah","Sivanesan",
            "Subramaniam","Chelvanayagam","Ramasamy","Thiruchelvam","Murugesan",
            "Kandasamy","Arulpragasam","Tharmalingam","Ponnusamy","Velupillai",
            "Yogarajah","Shanmugam","Jeyaratnam","Balasingam","Selvarajah",
            "Nadarajah","Kumarasamy","Pathmanathan","Sivapalan","Thangarajah",
            "Arasaratnam","Kanagaratnam","Rajaratnam","Sinnathamby","Thevarajah",
            "Uthayakumar","Vigneswaran","Balasubramaniam","Chandrakumar",
            "Dharmalingam","Gnanarajah","Iyathurai","Jeyakumar","Linganathan",
            "Mahalingam","Nagendran","Parameswaran","Rajendran","Sathiyaseelan",
            "Thambithurai","Varatharajan","Arumugam","Chelliah","Elankeswaran",
            "Ganeshalingam","Iyarasingam","Kanagasabai","Mahendrarajah","Nageswaran",
            "Ponnampalam","Rajeswaran","Sivananthan","Theiveegan","Veerasingham",
            "Aiyathurai","Balakumar","Chellarajah","Dharmaraj","Gnanasekaran",
            "Jeyaseelan","Kulanayagam","Mahadevan","Nanayakkara","Ravindran",
        ],
    },

    "muslim": {
        "male": [
            "Mohamed","Ahmed","Hassan","Ibrahim","Ismail","Farhan","Imran",
            "Rizwan","Fawaz","Thaslim","Shafraz","Aslam","Hameed","Rashid",
            "Zahir","Anwar","Siddiq","Nawaz","Rifaq","Munsif","Fahim","Riyaz",
            "Zubair","Haris","Amjad","Faisal","Nizar","Sajith","Irshadh",
            "Junaidh","Kaleel","Liyas","Musfir","Naufal","Osman","Parvez",
            "Qasim","Rafeek","Saleem","Thariq","Usman","Vaseem","Waleed",
            "Yaseen","Zaid","Abubakr","Bilal","Dawoodh","Farooq","Ghazali",
            "Hizbullah","Iqbal","Jameel","Khaled","Lathif","Mahmood","Naseem",
            "Obaidullah","Rafiq","Shahid","Tariq","Ubaid","Wajid","Yunus",
            "Abdulla","Basheer","Cafoor","Deen","Emran","Fareedh","Ghouse",
            "Hussain","Irshad","Jaleel","Kareem","Latheef","Mansoor","Niyaz",
            "Owais","Razeen","Sameer","Taufeeq","Umair","Zeeshan","Adeel",
            "Burhan","Dhilshan","Ershad","Faizal","Hafiz","Ishaq","Jabir",
            "Kabeer","Luqman","Marjan","Najeeb","Obaid","Rafeeq","Shakeel",
        ],
        "female": [
            "Fathima","Mariam","Aisha","Zainab","Nusrath","Hafsa","Ruqaiyya",
            "Shameela","Fareeda","Raseena","Samsiya","Hasifa","Ruhana","Nilufa",
            "Thasleema","Hafeeza","Amreen","Sumaiyya","Safiya","Jameela",
            "Nasreen","Hana","Suhana","Raisa","Zara","Ameena","Bushra",
            "Dilnoza","Eshal","Fathin","Gulshan","Humera","Inaya","Jaweria",
            "Khadeeja","Laraib","Malika","Nadia","Omayra","Raheema","Sabrina",
            "Tahira","Ummul","Warda","Yasmin","Zubeida","Anisa","Bilqis",
            "Chabina","Durdana","Farida","Ghazala","Hawwa","Iffath","Juwariya",
            "Kareema","Lubna","Munira","Naseema","Parvin","Rihana","Sajida",
            "Tasneem","Uzma","Washima","Yumna","Zahra","Abida","Barakath",
            "Dawood","Elaha","Fariha","Gulnara","Hadiya","Iram","Khadija",
            "Latifa","Madeeha","Nazmeen","Obeyda","Rabiya","Sadiya","Tahiyya",
            "Umayma","Wafaa","Yasmeen","Zulaikha","Amira","Bisma","Durra",
            "Fatimah","Hajar","Ikram","Kadija","Lamiya","Maimuna","Nabeela",
        ],
        "family": [
            "Lebbe","Naina","Marikar","Saldin","Jayah","Razik","Sheriff","Bawa",
            "Haniffa","Moulana","Cassim","Cader","Noor","Farook","Thassim",
            "Ameer","Raheem","Lafir","Nufail","Naleem","Wamiq","Haseen",
            "Munsif","Isadeen","Rifkhan","Rishard","Nawfal","Fahim","Imtiyas",
            "Junaid","Kariyapper","Lafeer","Marikkar","Naina","Obaidullah",
            "Pasha","Qadri","Razeek","Siddeeque","Thajudeen","Uvais","Vajid",
            "Wahab","Yoosuf","Zuhair","Aboobucker","Bakar","Dawood","Fathaudeen",
            "Ghawsudeen","Habeeb","Ifthikar","Jabbar","Khalifah","Lateef",
            "Mahmood","Noohu","Osaman","Rasheedeen","Sahabdeen","Tayyab",
            "Umardeen","Rafeekdeen","Saheed","Aroos","Burdhan","Caffoor",
            "Deen","Eburahim","Farook","Ghouse","Hassen","Ibraheem","Jainudeen",
            "Kamaludeen","Latiff","Marikkar","Nuhman","Piyal","Rahuman",
            "Sahadeen","Thoufiq","Usman","Waheedeen","Zakariyya","Macaan",
        ],
    },
}

# Ethnic weights: Sinhala 75 %, Tamil 15 %, Muslim 10 %
_ETHNICITIES    = ["sinhala", "tamil", "muslim"]
_ETHNIC_WEIGHTS = [0.75, 0.15, 0.10]

# ── Cities with population weights (approximate district pop in 100 K units) ──
# (city, province, postal_code, weight, nearest_hospital_key)
_CITIES = [
    ("Colombo",       "Western",        "00100", 23, "colombo"),
    ("Gampaha",       "Western",        "11000", 23, "colombo"),
    ("Kalutara",      "Western",        "12000", 12, "colombo"),
    ("Kandy",         "Central",        "20000", 14, "kandy"),
    ("Matale",        "Central",        "21000",  5, "kandy"),
    ("Nuwara Eliya",  "Central",        "22200",  7, "kandy"),
    ("Galle",         "Southern",       "80000", 11, "galle"),
    ("Matara",        "Southern",       "81000",  8, "matara"),
    ("Hambantota",    "Southern",       "82000",  6, "matara"),
    ("Jaffna",        "Northern",       "40000",  6, "jaffna"),
    ("Vavuniya",      "Northern",       "43000",  2, "jaffna"),
    ("Mannar",        "Northern",       "41000",  1, "jaffna"),
    ("Trincomalee",   "Eastern",        "31000",  4, "batticaloa"),
    ("Batticaloa",    "Eastern",        "30000",  5, "batticaloa"),
    ("Ampara",        "Eastern",        "32000",  7, "batticaloa"),
    ("Kurunegala",    "North Western",  "60000", 16, "kurunegala"),
    ("Puttalam",      "North Western",  "61000",  8, "kurunegala"),
    ("Anuradhapura",  "North Central",  "50000",  9, "anuradhapura"),
    ("Polonnaruwa",   "North Central",  "51000",  4, "anuradhapura"),
    ("Badulla",       "Uva",            "90000",  9, "badulla"),
    ("Monaragala",    "Uva",            "91000",  5, "badulla"),
    ("Ratnapura",     "Sabaragamuwa",   "70000", 11, "ratnapura"),
    ("Kegalle",       "Sabaragamuwa",   "71000",  8, "ratnapura"),
]
_CITY_WEIGHTS = [c[3] for c in _CITIES]

_HOSPITALS = {
    "colombo":      ("http://colombo-general.moh.lk/mr",     "CG"),
    "kandy":        ("http://kandy-teaching.moh.lk/mr",      "KT"),
    "galle":        ("http://galle-teaching.moh.lk/mr",      "GT"),
    "jaffna":       ("http://jaffna-teaching.moh.lk/mr",     "JT"),
    "kurunegala":   ("http://kurunegala-general.moh.lk/mr",  "KU"),
    "anuradhapura": ("http://anuradhapura-general.moh.lk/mr","AN"),
    "ratnapura":    ("http://ratnapura-general.moh.lk/mr",   "RP"),
    "badulla":      ("http://badulla-general.moh.lk/mr",     "BD"),
    "matara":       ("http://matara-general.moh.lk/mr",      "MT"),
    "batticaloa":   ("http://batticaloa-general.moh.lk/mr",  "BC"),
}
_HOSPITAL_KEYS = list(_HOSPITALS.keys())

_STREETS = [
    "Galle Road","Hospital Road","Temple Road","Main Street","School Lane",
    "Station Road","Lake Road","Kandy Road","Beach Road","Market Street",
    "Peradeniya Road","Baudhaloka Mawatha","Baseline Road","High Level Road",
    "Negombo Road","Kurunegala Road","Colombo Road","New Town Road",
    "Old Matara Road","Sirimavo Bandaranaike Mawatha","D.S. Senanayake Street",
    "Independence Avenue","Flower Road","Ward Place","Castle Street",
    "Duplication Road","Havelock Road","Union Place","Rajagiriya Road",
    "Nawala Road","Hokandara Road","Thalawathugoda Road","Polgolla Road",
    "Katugastota Road","Ampitiya Road","Dharmaraja Mawatha","Rajapihilla Mawatha",
    "Sangaraja Mawatha","Keppetipola Mawatha","Trincomalee Street",
    "Yatinuwara Veediya","Dalada Veediya","DS Senanayake Veediya",
    "Vihara Maha Devi Park Road","Sri Jayawardenepura Mawatha",
]

_MARITAL_CODES   = [("M","Married",0.55),("S","Never Married",0.30),
                    ("W","Widowed",0.10),("D","Divorced",0.05)]
_MARITAL_WEIGHTS = [m[2] for m in _MARITAL_CODES]


# ── Helpers ───────────────────────────────────────────────────────────────────

def rand_dob() -> str:
    """Triangular age distribution: mode 33 y, range 0–82 y."""
    age_years = int(random.triangular(0, 82, 33))
    birth = TODAY - timedelta(days=age_years * 365 + random.randint(0, 364))
    return birth.isoformat()


def rand_nic(birth_year: int, gender: str) -> str:
    """Generate a gender-aware NIC.
    Old format (< 2000): YYDDDNNNV/X  — females add 500 to DDD.
    New format (>= 2000): YYYYDDDNNNC — females add 500 to DDD."""
    ddd = random.randint(1, 366)
    if gender == "female":
        ddd += 500
    serial = random.randint(100, 999)
    if birth_year < 2000:
        check = random.choice(["V", "X"])
        return f"{birth_year % 100:02d}{ddd:03d}{serial}{check}"
    check = random.randint(0, 9)
    return f"{birth_year}{ddd:03d}{serial}{check}"


def rand_phone() -> str:
    prefix = random.choice(["071","072","075","076","077","078"])
    return f"+94{prefix[1:]}{random.randint(1000000, 9999999)}"


def rand_mrn(prefix: str, n: int) -> str:
    return f"{prefix}-{n:06d}"


def pick_city() -> tuple:
    return random.choices(_CITIES, weights=_CITY_WEIGHTS, k=1)[0]


def pick_hospital(city_row: tuple) -> tuple:
    # 70 % chance of nearest provincial hospital, 30 % any hospital
    key = city_row[4] if random.random() < 0.70 else random.choice(_HOSPITAL_KEYS)
    return _HOSPITALS[key]


def build_patient(idx: int, ethnicity: str, gender: str,
                  dob: str, phone: str, nic: str,
                  city_row: tuple, hospital: tuple) -> dict:
    pool   = _NAMES[ethnicity]
    given  = [random.choice(pool[gender])]
    if random.random() < 0.30:          # 30 % have a second given name
        given.append(random.choice(pool[gender]))
    family = random.choice(pool["family"])

    hosp_sys, hosp_pfx = hospital
    city, province, postal, *_ = city_row

    identifiers = [{"use": "official", "system": hosp_sys,
                    "value": rand_mrn(hosp_pfx, idx)}]
    if nic:
        identifiers.append({"use": "official",
                             "system": "http://moh.gov.lk/nic", "value": nic})

    patient: dict = {
        "resourceType": "Patient",
        "identifier": identifiers,
        "active": True,
        "name": [{"use": "official", "family": family, "given": given}],
        "telecom": [
            {"system": "phone", "value": phone, "use": "mobile"},
            {"system": "email",
             "value": f"{given[0].lower()}.{family.lower()}{idx}@lk.example",
             "use": "home"},
        ],
        "gender": gender,
        "birthDate": dob,
        "address": [{
            "use": "home",
            "line": [f"{random.randint(1,500)} {random.choice(_STREETS)}"],
            "city": city,
            "district": province,
            "postalCode": postal,
            "country": "LK",
        }],
    }

    # mothersMaidenName extension on 60 % of records
    if random.random() < 0.60:
        patient["extension"] = [{
            "url": "http://hl7.org/fhir/StructureDefinition/patient-mothersMaidenName",
            "valueString": random.choice(pool["family"]),
        }]

    # maritalStatus for adults (18 +)
    age = (TODAY - date.fromisoformat(dob)).days // 365
    if age >= 18:
        code, display, *_ = random.choices(_MARITAL_CODES,
                                          weights=_MARITAL_WEIGHTS, k=1)[0]
        patient["maritalStatus"] = {
            "coding": [{"system":
                        "http://terminology.hl7.org/CodeSystem/v3-MaritalStatus",
                        "code": code, "display": display}]
        }

    return patient


def mutate_for_duplicate(patient: dict) -> dict:
    """Return a realistic duplicate: always a NEW MRN (separate registration event),
    NIC retained only 60 % of the time, plus one demographic variation."""
    dup = copy.deepcopy(patient)

    # Every duplicate originates from a separate registration — always a new MRN,
    # possibly at a different hospital.
    new_key             = random.choice(_HOSPITAL_KEYS)
    new_hosp_sys, new_pfx = _HOSPITALS[new_key]
    new_mrn             = rand_mrn(new_pfx, random.randint(1, 999_999))

    # Clerks re-enter NIC only ~60 % of the time
    nic_ids = [i for i in dup["identifier"] if "nic" in i.get("system", "")]
    if random.random() < 0.60 and nic_ids:
        dup["identifier"] = [{"use": "official", "system": new_hosp_sys, "value": new_mrn}] + nic_ids
    else:
        dup["identifier"] = [{"use": "official", "system": new_hosp_sys, "value": new_mrn}]

    # One additional demographic variation
    mutation = random.choice(["typo_given", "typo_family", "diff_phone",
                               "diff_address", "missing_second_given"])

    if mutation == "typo_given":
        g = dup["name"][0]["given"][0]
        if len(g) >= 3:
            i = random.randint(0, len(g) - 2)
            g = g[:i] + g[i+1] + g[i] + g[i+2:]
        dup["name"][0]["given"][0] = g

    elif mutation == "typo_family":
        f = dup["name"][0]["family"]
        if len(f) >= 3:
            i = random.randint(1, len(f) - 2)
            f = f[:i] + f[i+1] + f[i] + f[i+2:]
        dup["name"][0]["family"] = f

    elif mutation == "diff_phone":
        dup["telecom"][0]["value"] = rand_phone()

    elif mutation == "diff_address":
        ct = pick_city()
        dup["address"][0].update({"city": ct[0], "district": ct[1], "postalCode": ct[2]})

    elif mutation == "missing_second_given":
        # Drop the second given name if present (clerk enters only first name)
        if len(dup["name"][0].get("given", [])) > 1:
            dup["name"][0]["given"] = [dup["name"][0]["given"][0]]

    return dup


# ── Main generation loop ──────────────────────────────────────────────────────

def generate_to_file(output_path: str, total_base: int = TOTAL_BASE) -> int:
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)

    written  = 0
    buffer   = []
    FLUSH_AT = 1_000

    with open(output_path, "w", encoding="utf-8") as fh:
        for i in range(1, total_base + 1):
            ethnicity  = random.choices(_ETHNICITIES, weights=_ETHNIC_WEIGHTS, k=1)[0]
            gender     = random.choice(["male", "female"])
            dob        = rand_dob()
            birth_year = int(dob[:4])
            phone      = rand_phone()
            nic        = rand_nic(birth_year, gender) if random.random() > 0.10 else ""
            city_row   = pick_city()
            hospital   = pick_hospital(city_row)

            p = build_patient(i, ethnicity, gender, dob, phone, nic, city_row, hospital)
            buffer.append(json.dumps(p, separators=(",", ":")))
            written += 1

            if random.random() < DUP_RATE:
                buffer.append(json.dumps(mutate_for_duplicate(p), separators=(",", ":")))
                written += 1

            if len(buffer) >= FLUSH_AT:
                fh.write("\n".join(buffer) + "\n")
                buffer.clear()

            if total_base >= LOG_EVERY and i % LOG_EVERY == 0:
                print(f"  Generated {i:,} base patients ({written:,} total records)...")

        if buffer:
            fh.write("\n".join(buffer) + "\n")

    return written


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(
        description="Generate realistic Sri Lankan FHIR patients to NDJSON")
    parser.add_argument("--count", type=int, default=TOTAL_BASE,
                        help=f"Number of base (unique) patients (default: {TOTAL_BASE})")
    parser.add_argument("--output", type=str, default=OUTPUT_FILE,
                        help=f"Output NDJSON file path (default: {OUTPUT_FILE})")
    args = parser.parse_args()

    print(f"Generating {args.count:,} base patients "
          f"(Sinhala 75%/Tamil 15%/Muslim 10%, {int(DUP_RATE*100)}% dup rate)...")
    total = generate_to_file(args.output, args.count)
    print(f"Done. {total:,} records written to {args.output}")
    print("Next step: run bulk_insert_patients.py to load into PostgreSQL.")
