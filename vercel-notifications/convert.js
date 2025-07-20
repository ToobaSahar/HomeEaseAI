import fs from 'fs/promises';

try {
  const raw = await fs.readFile('./homeeaseai-firebase-adminsdk-fbsvc-1f18df8311.json', 'utf8');
  const escaped = JSON.stringify(JSON.parse(raw));
  console.log(escaped);
} catch (error) {
  console.error("❌ Error reading/parsing JSON:", error.message);
}
