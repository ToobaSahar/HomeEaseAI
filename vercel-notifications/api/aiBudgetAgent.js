import fetch from 'node-fetch';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  const { income, expenses } = req.body;

  if (!income || !expenses || typeof income !== 'number' || typeof expenses !== 'object') {
    return res.status(400).json({ error: 'Invalid input' });
  }

  const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
  const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`;

  const expenseDetails = Object.entries(expenses)
    .map(([key, val]) => `- ${key}: Rs. ${Number(val).toFixed(2)}`)
    .join('\n');

  const userPrompt = `
You are a smart, helpful budget planner AI.

A user earns Rs. ${income.toFixed(2)} per month and has reported the following monthly expenses:

${expenseDetails}

Please perform the following:
1. Calculate the total monthly expenses (add all categories).
2. Calculate savings using: Savings = Income - Total Expenses.
3. Provide a brief summary showing:
   - Monthly Income
   - Total Expenses
   - Estimated Savings
   - (Include calculation steps clearly.)
4. Provide 2–3 smart and personalized suggestions to reduce overspending or improve savings.

📋 Your response must strictly follow this format:
Summary:
- Monthly Income: ...
- Total Expenses: ...
- Estimated Savings: ...
- Calculation: Income - Expenses = Savings

Suggestion:
1. ...
2. ...
3. ...
`;

  const body = {
    contents: [
      {
        role: 'user',
        parts: [{ text: userPrompt }],
      },
    ],
  };

  try {
    const response = await fetch(geminiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });

    const result = await response.json();
    console.log('🔍 Gemini raw response:', JSON.stringify(result, null, 2));

    const content = result?.candidates?.[0]?.content?.parts?.[0]?.text || '';

    // Extract summary and suggestion sections
    const summaryMatch = content.match(/Summary:\s*(.*?)(?=Suggestion:)/s);
    const suggestionMatch = content.match(/Suggestion:\s*(.*)/s);

    // Return structured JSON
    res.status(200).json({
      summary: (summaryMatch?.[1] || '').trim(),
      suggestion: (suggestionMatch?.[1] || '').trim(),
    });
  } catch (error) {
    console.error('Gemini API error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
}
