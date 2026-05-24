class AppConstants {
  // Emergency Numbers for Bangladesh
  static const String policeEmergencyNumber = "999";
  static const String rabEmergencyNumber = "01777720099";
  static const String defaultSosMessage = "EMERGENCY! I need help. My current location is: ";
  
  // UI Paddings
  static const double defaultPadding = 16.0;
  static const double extraPadding = 24.0;
  
  // Twilio Settings (FOR PROTOTYPE ONLY - Use Cloud Functions for Production)
  static const String twilioAccountSid = "YOUR_TWILIO_ACCOUNT_SID";
  static const String twilioAuthToken = "YOUR_TWILIO_AUTH_TOKEN";
  static const String twilioFromNumber = "YOUR_TWILIO_FROM_NUMBER";
  
  // Location Updating
  static const int locationUpdateIntervalMinutes = 15;

  // EmailJS — sign up free at https://www.emailjs.com
  // Create a service, template with variables: {{to_name}}, {{otp_code}}, {{to_email}}
  // Then paste your IDs below.
  static const String emailJsServiceId  = 'YOUR_EMAILJS_SERVICE_ID';   // e.g. 'service_abc123'
  static const String emailJsTemplateId = 'YOUR_EMAILJS_TEMPLATE_ID';  // e.g. 'template_xyz456'
  static const String emailJsPublicKey  = 'YOUR_EMAILJS_PUBLIC_KEY';   // e.g. 'abcXYZ123...'
}
