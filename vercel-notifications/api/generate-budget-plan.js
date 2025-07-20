import fetch from 'node-fetch';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  const { income, savingGoal } = req.body;

  if (
    typeof income !== 'number' ||
    typeof savingGoal !== 'number' ||
    income <= 0 ||
    savingGoal < 0 ||
    savingGoal > income
  ) {
    return res.status(400).json({ error: 'Invalid income or saving goal' });
  }

  const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
  const availableForExpenses = income - savingGoal;

  const prompt = `
You are an intelligent budgeting assistant.

A user earns Rs. ${income.toFixed(0)} per month and wants to save Rs. ${savingGoal.toFixed(0)}.

Please follow these instructions carefully:

1. Subtract the savings (Rs. ${savingGoal.toFixed(0)}) from the income (Rs. ${income.toFixed(0)}). This gives the available amount for expenses: Rs. ${availableForExpenses.toFixed(0)}.
2. Distribute **exactly Rs. ${availableForExpenses.toFixed(0)}** into realistic Pakistani urban monthly expense categories using local cost-of-living standards. 
   Use these categories: Rent, Food, Transport, Utilities, Healthcare, Entertainment, Education, Miscellaneous.
3. The **sum of all categories must equal exactly Rs. ${availableForExpenses.toFixed(0)}**. Double-check your totals before responding. 
   Do not exceed or fall short of this amount — you must verify the math.
4. Format your response like this:
Categories:
- Rent: Rs. XXXX
- Food: Rs. XXXX
- Transport: Rs. XXXX
...
Summary: (one-line summary)
Suggestion: (3 to 4 budgeting tips)

⚠️ Very Important:
- Do not write any explanation outside this format.
- Ensure all category values are whole numbers in Rs., no fractions or decimals.
- Ensure the total sum matches Rs. ${availableForExpenses.toFixed(0)} exactly — verify this before finishing.
`;

  const body = {
    contents: [
      {
        role: 'user',
        parts: [{ text: prompt }],
      },
    ],
  };

  try {
    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`;

    const response = await fetch(geminiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });

    const result = await response.json();
    const content = result?.candidates?.[0]?.content?.parts?.[0]?.text ?? '';

    if (!content) {
      console.warn('No content returned from Gemini');
      return res.status(200).json({
        categories: {},
        summary: '⚠ Empty response from Gemini model.',
        suggestion: 'Try again with adjusted input or check Gemini API usage.',
        raw: '',
      });
    }

    // Parse categories
    const categories = {};
    const categoryRegex = /-\s*(.*?):\s*Rs\.?\s*([\d,]+)/gi;
    let match;

    while ((match = categoryRegex.exec(content)) !== null) {
      const name = match[1].trim();
      const amount = parseFloat(match[2].replace(/,/g, ''));
      if (!isNaN(amount)) {
        categories[name] = amount;
      }
    }

    // Extract summary and suggestions
    const summaryMatch = content.match(/Summary:\s*(.*?)\n/s);
    const suggestionMatch = content.match(/Suggestion:\s*(.*)/s);

    res.status(200).json({
      categories,
      summary: summaryMatch?.[1]?.trim() ?? '',
      suggestion: suggestionMatch?.[1]?.trim() ?? '',
      raw: content, // helpful for debugging
    });
  } catch (error) {
    console.error('Gemini generate-budget-plan error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
}
