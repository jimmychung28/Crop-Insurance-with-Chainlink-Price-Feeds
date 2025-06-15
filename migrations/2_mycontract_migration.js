const InsuranceProvider = artifacts.require("InsuranceProvider");
require('dotenv').config();

module.exports = function(deployer) {
  // Get API keys from environment variables
  const worldWeatherOnlineKey = process.env.WORLD_WEATHER_ONLINE_KEY;
  const openWeatherKey = process.env.OPEN_WEATHER_KEY;
  const weatherbitKey = process.env.WEATHERBIT_KEY;

  // Validate that all required API keys are present
  if (!worldWeatherOnlineKey || !openWeatherKey || !weatherbitKey) {
    throw new Error('Missing required API keys in .env file. Please set WORLD_WEATHER_ONLINE_KEY, OPEN_WEATHER_KEY, and WEATHERBIT_KEY');
  }

  console.log('Deploying InsuranceProvider with API keys...');
  console.log('World Weather Online Key:', worldWeatherOnlineKey ? '***' + worldWeatherOnlineKey.slice(-4) : 'NOT SET');
  console.log('OpenWeather Key:', openWeatherKey ? '***' + openWeatherKey.slice(-4) : 'NOT SET');
  console.log('Weatherbit Key:', weatherbitKey ? '***' + weatherbitKey.slice(-4) : 'NOT SET');

  deployer.deploy(
    InsuranceProvider,
    worldWeatherOnlineKey,
    openWeatherKey,
    weatherbitKey
  );
};	