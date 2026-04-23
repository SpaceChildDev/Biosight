# Biosight Privacy Policy

**Last updated: April 2026**

This privacy policy describes how the Biosight mobile application ("App") handles your personal data.

---

## 1. Our Core Principle

Biosight is designed around **data minimization**. Your health data is stored only on your device and in your iCloud account. The App has no server of its own.

---

## 2. Data Collected and Processed

### 2.1 Data Stored on Your Device (Never Transmitted)

| Data Type | Purpose | Where Stored |
|-----------|---------|--------------|
| Lab results (value name, numeric value, unit, reference range) | Personal health tracking | Device (SwiftData) + iCloud |
| Uploaded PDF files | Access to original document | Device local storage |
| Person profiles (name, date of birth) | Family member tracking | Device (SwiftData) + iCloud |
| Apple Health data (heart rate, sleep, step count, etc.) | Health metric display | Device only |
| App preferences and settings | Personalization | Device (UserDefaults) |

### 2.2 Data Optionally Sent to Third Parties

**Google Gemini AI (optional)**

When you use the AI-powered PDF analysis or value description feature, only the following data is sent to Google's Gemini API:

- Lab values from your report (numeric values, units, reference ranges)
- Value names (e.g., "ALT", "TSH", "Hemoglobin")

**Data NOT sent:** Your name, surname, date of birth, national ID number, patient number, or any other personal identifiers are never sent to Gemini.

This feature is entirely optional. You can use it by entering your own Gemini API key. If you choose not to provide an API key, this feature remains disabled.

Google's data processing policy: [https://policies.google.com/privacy](https://policies.google.com/privacy)

### 2.3 Anonymous Usage Data

Biosight records which laboratory value names (e.g., "Erythrocyte", "TSH", "Beta-2 Microglobulin") are frequently used, **anonymously only**. This data:

- Does **not** contain numeric values, results, or personal information
- **Cannot** be linked to your device or identity
- Is used to determine which values need descriptions added to the knowledge base

This feature is implemented transparently to help users access more comprehensive health information.

---

## 3. Apple HealthKit

Biosight accesses Apple HealthKit data for **read-only** purposes. No data obtained from HealthKit is transmitted to third parties, used for advertising, or stored on any external server.

Data types accessed: heart rate, resting heart rate, oxygen saturation, blood glucose, blood pressure, weight, BMI, sleep duration, step count, active calories, respiratory rate, and other health metrics.

HealthKit access can be revoked at any time from device Settings > Health.

---

## 4. iCloud Backup

When iCloud backup is enabled, your lab results and profile information are stored encrypted on Apple's iCloud infrastructure. This data is accessible only with your Apple ID.

Apple's iCloud privacy policy: [https://www.apple.com/legal/privacy/](https://www.apple.com/legal/privacy/)

---

## 5. Data Security

- Your health data is stored encrypted on your device through iOS's secure storage layer (SwiftData).
- The App has no server, database, or analytics system of its own.
- PDF files are saved only to your device's local storage.

---

## 6. Children's Privacy

Biosight does not target or knowingly collect data from individuals under the age of 13. If a parent or legal guardian becomes aware that their child's information has been entered into the App, they may contact us.

---

## 7. Deleting Your Data

You can delete all your data within the App as follows:

- **Lab data:** Settings > Delete All Data
- **PDF files:** Manual deletion from the Imported Files screen
- **Cache and preferences:** Deleting the App from your device removes all local data

---

## 8. Third-Party Links

Academic sources within the App (PubMed, WHO, NIH, etc.) may contain links to external websites. Biosight is not responsible for the privacy practices of those sites.

---

## 9. Changes to This Policy

When our privacy policy is updated, the "Last updated" date on this page will change. In-app notifications may be provided for significant changes.

---

## 10. Contact

For questions about our privacy policy:

**Email:** dagkan@spacechild.dev

---

*Biosight believes your health data belongs to you. Transparency and respect for privacy are core design principles of the App.*
