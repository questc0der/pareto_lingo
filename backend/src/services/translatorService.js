const axios = require("axios");

async function translateWord({ word, sourceLanguage, targetLanguage }) {
  try {
    const response = await axios.get(
      "https://translate.googleapis.com/translate_a/single",
      {
        params: {
          client: "gtx",
          sl: sourceLanguage,
          tl: targetLanguage,
          dt: "t",
          q: word,
        },
        timeout: 15000,
      },
    );

    const data = response.data;
    const translated =
      Array.isArray(data) &&
      Array.isArray(data[0]) &&
      Array.isArray(data[0][0]) &&
      data[0][0][0]
        ? String(data[0][0][0]).trim()
        : "";

    if (!translated) {
      return word;
    }

    return translated;
  } catch (_) {
    return word;
  }
}

async function mapWithConcurrency(items, concurrency, mapper) {
  const results = new Array(items.length);
  let currentIndex = 0;

  const workers = Array.from({ length: Math.max(1, concurrency) }, async () => {
    while (currentIndex < items.length) {
      const index = currentIndex;
      currentIndex += 1;
      results[index] = await mapper(items[index], index);
    }
  });

  await Promise.all(workers);
  return results;
}

module.exports = {
  translateWord,
  mapWithConcurrency,
};
