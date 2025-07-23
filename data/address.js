// Location detection utilities
window.locationUtils = {
  // Get user's current location
  async getCurrentLocation() {
    return new Promise((resolve, reject) => {
      if (!navigator.geolocation) {
        reject(new Error('Geolocation is not supported by this browser'));
        return;
      }

      navigator.geolocation.getCurrentPosition(
        (position) => {
          resolve({
            latitude: position.coords.latitude,
            longitude: position.coords.longitude,
            accuracy: position.coords.accuracy
          });
        },
        (error) => {
          reject(error);
        },
        {
          enableHighAccuracy: true,
          timeout: 10000,
          maximumAge: 0
        }
      );
    });
  },

  // Get location details from coordinates using reverse geocoding
  async getLocationFromCoordinates(latitude, longitude) {
    try {
      // Using OpenStreetMap Nominatim API for reverse geocoding with higher zoom for better administrative detail
      const response = await fetch(
        `https://nominatim.openstreetmap.org/reverse?format=json&lat=${latitude}&lon=${longitude}&zoom=12&addressdetails=1&accept-language=en`
      );

      if (!response.ok) {
        throw new Error('Failed to fetch location data');
      }

      const data = await response.json();
      console.log('Location API response:', data);

      // Extract district and upazila information
      const address = data.address || {};

      // For Bangladesh, try different administrative levels
      let district = '';
      let upazila = '';

      // District mapping - try different fields
      if (address.state_district) {
        district = address.state_district;
      } else if (address.county) {
        district = address.county;
      } else if (address.state) {
        district = address.state;
      } else if (address.city) {
        district = address.city;
      }

      // Upazila mapping - try different administrative levels
      // For Bangladesh, upazila is often found in city field when it's not the main district city
      if (address.municipality) {
        upazila = address.municipality;
      } else if (address.town) {
        upazila = address.town;
      } else if (address.suburb) {
        upazila = address.suburb;
      } else if (address.city_district) {
        upazila = address.city_district;
      } else if (address.neighbourhood) {
        upazila = address.neighbourhood;
      } else if (address.village) {
        upazila = address.village;
      } else if (address.city && address.city !== district) {
        // If city is different from district, it might be the upazila
        upazila = address.city;
      }
      
      // Special handling for major cities that are also districts
      if (address.city === district && district) {
        // For district headquarters, use "Sadar" as upazila
        upazila = `${district} Sadar`;
      }

      // Clean up names (remove common suffixes)
      district = district.replace(/\s+(District|Zilla)$/i, '').trim();
      upazila = upazila.replace(/\s+(Upazila|Thana|Sadar)$/i, '').trim();

      // If still no upazila found, try alternative API
      if (!upazila && district) {
        try {
          const alternativeData = await this.getAlternativeLocationData(latitude, longitude);
          if (alternativeData.upazila) {
            upazila = alternativeData.upazila;
          }
        } catch (altError) {
          console.log('Alternative location API failed:', altError);
        }
      }

      const result = {
        district: district || '',
        upazila: upazila || ''
      };

      console.log('Extracted location data:', result);
      return result;
    } catch (error) {
      console.error('Error getting location details:', error);
      throw error;
    }
  }
};