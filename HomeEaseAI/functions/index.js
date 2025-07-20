const functions = require("firebase-functions");
const express = require("express");
const cors = require("cors");
const fetch = require("node-fetch");

const app = express();
app.use(cors({ origin: true }));

const GEMINI_API_KEY = functions.config().gemini.apikey;

app.post("/analyze-bill", async (req, res) => {
  try {
    const base64Image = req.body.base64Image;

    if (!base64Image) {
      res.status(400).json({ error: "No image provided" });
      return;
    }

    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=${GEMINI_API_KEY}`;

    const body = {
      contents: [
        {
          parts: [
            {
              text:
                "This is an electricity bill image. Extract total units, total amount, and any usage-related notes. " +
                "Then suggest 3–5 personalized ways to reduce the bill.",
            },
            {
              inlineData: {
                mimeType: "image/jpeg",
                data: base64Image,
              },
            },
          ],
        },
      ],
    };

    const response = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    const result = await response.json();

    if (!response.ok) {
      res.status(500).json({ error: result });
      return;
    }

    const text =
      result?.candidates?.[0]?.content?.parts?.[0]?.text || "No result found";

    res.json({ message: text });
  } catch (err) {
    console.error("Error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

exports.geminiBillAgent = functions.https.onRequest(app);
