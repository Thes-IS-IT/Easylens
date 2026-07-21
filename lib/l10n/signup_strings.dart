// lib/l10n/signup_strings.dart
// Localization strings for the EasyLens signup wizard.
// Supports 'English' (default) and 'Filipino' (Tagalog).

class SignupL10n {
  static const Map<String, Map<String, String>> _strings = {
    'en': {
      // ── Navigation / Global ──────────────────────────────────────────
      'back': 'Back',
      'continue': 'Continue',
      'finish_setup': 'Finish setting up',

      // ── Step 1: Language ─────────────────────────────────────────────
      'language_title': 'Choose your language',
      'language_subtitle': 'Which language would you like the app to use?',
      'language_english': 'English',
      'language_filipino': 'Filipino',

      // ── Step 1b: Signup Mode ─────────────────────────────────────────
      'mode_title': 'Registration Method',
      'mode_subtitle': 'How would you like to set up your account?',
      'mode_voice_title': 'Voice Command Fillup',
      'mode_voice_desc': 'Buddy will read steps out loud and listen for your voice choices and commands.',
      'mode_manual_title': 'Manual Form Fillup',
      'mode_manual_desc': 'Fill up the onboarding wizard manually using touch buttons.',

      // ── Step 2: Persona ──────────────────────────────────────────────
      'persona_title': 'Who is this for?',
      'persona_subtitle': 'Tell us who will be using the app so we can tailor the experience.',
      'persona_myself': 'Myself',
      'persona_someone_else': 'Someone Else',

      // ── Step 3: Conditions ───────────────────────────────────────────
      'conditions_title': 'Your Conditions',
      'conditions_subtitle': 'Select any vision needs you have so we can set up the app to help you best.',
      'conditions_not_listed': 'Condition not listed...',

      // ── Step 3b: Other Condition ─────────────────────────────────────
      'other_condition_title': 'What is your condition?',
      'other_condition_subtitle': 'Tell us about your vision condition so we can customize the app for you.',
      'other_condition_mic_label': 'Tap to speak your condition',
      'other_condition_hint': 'e.g. Nystagmus, Strabismus...',
      'other_condition_add': 'Add this condition',
      'other_condition_cancel': 'Cancel',

      // ── Step 4: Contrast Theme ───────────────────────────────────────
      'theme_title': 'Contrast Theme',
      'theme_subtitle': 'Select the color interface to maximize text legibility.',

      // ── Step 5: Accessibility ────────────────────────────────────────
      'accessibility_title': 'Helpful cues',
      'accessibility_subtitle': 'Choose how you would like the app to talk or vibrate.',
      'accessibility_voice': 'Voice guides',
      'accessibility_haptic': 'Vibration cues',

      // ── Step 6: Voice Persona ────────────────────────────────────────
      'voice_persona_title': 'Choose a voice',
      'voice_persona_subtitle': 'Which voice tone feels most comfortable and easy to listen to?',
      'voice_aria_desc': 'A soft, reassuring voice to guide you.',
      'voice_max_desc': 'A clear, confident voice that stands out.',
      'voice_nova_desc': 'An active, friendly voice full of energy.',
      'voice_echo_desc': 'A deep, clear voice.',
      'voice_bella_desc': 'A calm, slow voice to help you focus.',
      'voice_leo_desc': 'A bright, cheerful young voice.',

      // ── Step 7: Mobility Aids ────────────────────────────────────────
      'mobility_title': 'Walking & navigation tools',
      'mobility_subtitle': 'Do you use any of these to help you move around?',
      'mobility_white_cane': 'White Cane',
      'mobility_guide_dog': 'Guide Dog',
      'mobility_smart_glasses': 'Smart Glasses',
      'mobility_eyeglasses': 'Eyeglasses',
      'mobility_wheelchair': 'Wheelchair',
      'mobility_walker': 'Walker',
      'mobility_sighted_guide': 'Sighted Guide',
      'mobility_none': 'None',

      // ── Step 8: Create Account ───────────────────────────────────────
      'create_account_title': "Let's create your account",
      'create_account_subtitle': 'How would you prefer to sign in?',
      'create_account_google': 'Google',
      'create_account_email': 'Email',

      // ── Step 9: Email Input ──────────────────────────────────────────
      'email_title': 'What is your email address?',
      'email_subtitle': "We'll use this to send you important updates about your account.",
      'email_hint': 'Your email address',
      'email_continue': 'Continue',
      'email_change_method': 'Use a different method',

      // ── Step 10: Phone Input ─────────────────────────────────────────
      'phone_title': 'What is your phone number?',
      'phone_subtitle': "We'll send a one-time code to verify it's really you.",
      'phone_hint': 'Your phone number',
      'phone_send_code': 'Send me a code',
      'phone_change_method': 'Use a different method',

      // ── Step 10b: Verification Code ──────────────────────────────────
      'verify_title': 'Enter your code',
      'verify_subtitle': 'Please enter the 4-digit code we just sent to your phone.',
      'verify_no_code': "Didn't receive the code?",
      'verify_resend': 'Send it again',
      'verify_confirm': 'Confirm',
      'verify_error_resend': "We couldn't resend the code. Please try again.",

      // ── Step 11: Create Password ─────────────────────────────────────
      'password_title': 'Choose a password',
      'password_subtitle': 'Pick a password that is easy for you to remember, but hard for others to guess.',
      'password_enter': 'Enter password',
      'password_confirm_field': 'Type password again',
      'password_keep_signed_in': 'Keep me signed in',

      // ── Step 12: Permissions ─────────────────────────────────────────
      'permissions_title': 'Enable features',
      'permissions_subtitle': 'To get started, we need a few permissions to help you navigate.',
      'permissions_camera': 'Camera (to see your surroundings)',
      'permissions_microphone': 'Microphone (to hear your voice commands)',
      'permissions_location': 'Location (to guide you on your route)',
      'permissions_bluetooth': 'Bluetooth (to connect with assistive devices)',

      // ── Step 13: Terms & Privacy ─────────────────────────────────────
      'terms_title': 'Our commitment to you',
      'terms_agree': 'I agree',
      'terms_read': 'Read in full',
      'terms_body': 'By proceeding, you agree to our terms and privacy policy.',
      'terms_local_label': 'Everything stays on your phone',
      'terms_local_body': 'EasyLens processes your camera and location details directly on your device to keep your navigation fast and private.',
      'terms_privacy_label': 'Your privacy comes first',
      'terms_privacy_body': 'We never record what your camera sees, and we keep your information private and secure. We never sell your data.',

      // ── Step 14: Upload Photo ────────────────────────────────────────
      'photo_title': 'Add a photo',
      'photo_subtitle': 'Add a picture of yourself so your friends and helpers can recognize you.',
      'photo_gallery': 'Choose from gallery',
      'photo_camera': 'Take a new photo',
      'photo_choose': 'Choose a photo',
      'photo_skip': 'Skip for now',

      // ── Step 15: Photo Confirmation ──────────────────────────────────
      'photo_confirm_title': 'Looks great!',
      'photo_confirm_subtitle': 'Here is how your profile picture will look.',
      'photo_confirm_reupload': 'Choose a different photo',
      'photo_confirm_continue': 'Looks good, continue',

      // ── Step 16: Name Input ──────────────────────────────────────────
      'name_title': 'What should I call you?',
      'name_subtitle': 'Tap the microphone to speak your name, or type it below.',
      'name_mic_label': 'Tap to speak your name',
      'name_write_here': 'Or write it here:',
      'name_hint': 'Your name or nickname',

      // ── Step 17: Birthday Input ──────────────────────────────────────
      'birthday_title': 'When is your birthday?',
      'birthday_subtitle': 'You can tap the microphone to say it, or write it below.',
      'birthday_mic_label': 'Tap to speak your birthday',
      'birthday_calendar': 'Or choose from the calendar:',

      // ── Step 18: SOS Contact ─────────────────────────────────────────
      'sos_title': 'Emergency contact',
      'sos_subtitle': "Who should we contact in an emergency? We'll send them an alert if you need immediate help.",
      'sos_import': 'Choose from contacts',
      'sos_or_manual': 'or write details below',
      'sos_their_name': 'THEIR FULL NAME',
      'sos_their_phone': 'THEIR PHONE NUMBER',
      'sos_relationship': 'HOW DO YOU KNOW THEM? (E.G. SISTER, FRIEND)',
      'sos_finish': 'Finish setting up',

      // ── Units ────────────────────────────────────────────────────────
      'units_title': 'Distance measurements',
      'units_subtitle': 'How would you prefer the app to read out distances?',
      'units_metric': 'Metric',
      'units_imperial': 'Imperial',

      // ── Validation Errors ────────────────────────────────────────────
      'error_email': 'Please enter a valid email address (e.g. name@example.com)',
      'error_phone': 'Please enter a valid 11-digit phone number',
      'error_password_empty': 'Please create a password for your account',
      'error_password_short': 'Password must be at least 6 characters long',
      'error_name': 'Please enter your name or nickname',
    },

    'fil': {
      // ── Navigation / Global ──────────────────────────────────────────
      'back': 'Bumalik',
      'continue': 'Ituloy',
      'finish_setup': 'Tapusin ang pag-setup',

      // ── Step 1: Language ─────────────────────────────────────────────
      'language_title': 'Piliin ang iyong wika',
      'language_subtitle': 'Anong wika ang gusto mong gamitin ng app?',
      'language_english': 'English',
      'language_filipino': 'Filipino',

      // ── Step 1b: Signup Mode ─────────────────────────────────────────
      'mode_title': 'Paraan ng Pagpaparehistro',
      'mode_subtitle': 'Paano mo gustong sagutan ang pag-setup ng iyong account?',
      'mode_voice_title': 'Voice Command Fillup (Gamit ang Boses)',
      'mode_voice_desc': 'Babasahin ni Buddy ang mga hakbang at makikinig sa iyong boses para sa mga pili.',
      'mode_manual_title': 'Manwal na Pagpuno (Gamit ang Pindot)',
      'mode_manual_desc': 'Sagutan ang onboarding wizard gamit ang karaniwang mga pindutan.',

      // ── Step 2: Persona ──────────────────────────────────────────────
      'persona_title': 'Para kanino ito?',
      'persona_subtitle': 'Sabihin sa amin kung sino ang gagamit ng app para ma-tailor namin ang karanasan.',
      'persona_myself': 'Para sa akin',
      'persona_someone_else': 'Para sa iba',

      // ── Step 3: Conditions ───────────────────────────────────────────
      'conditions_title': 'Iyong mga kondisyon',
      'conditions_subtitle': 'Piliin ang anumang pangangailangan sa paningin mo para maayos namin ang app para sa iyo.',
      'conditions_not_listed': 'Hindi nakalista ang kondisyon...',

      // ── Step 3b: Other Condition ─────────────────────────────────────
      'other_condition_title': 'Ano ang iyong kondisyon?',
      'other_condition_subtitle': 'Sabihin sa amin ang iyong kondisyon sa paningin para ma-customize namin ang app para sa iyo.',
      'other_condition_mic_label': 'I-tap para sabihin ang iyong kondisyon',
      'other_condition_hint': 'hal. Nystagmus, Strabismus...',
      'other_condition_add': 'Idagdag ang kondisyong ito',
      'other_condition_cancel': 'Kanselahin',

      // ── Step 4: Contrast Theme ───────────────────────────────────────
      'theme_title': 'Tema ng Kontras',
      'theme_subtitle': 'Pumili ng kulay ng interface para sa mas malinaw na pagbasa.',

      // ── Step 5: Accessibility ────────────────────────────────────────
      'accessibility_title': 'Mga tulong na pahiwatig',
      'accessibility_subtitle': 'Piliin kung paano mo gustong magsalita o mag-vibrate ang app.',
      'accessibility_voice': 'Gabay sa boses',
      'accessibility_haptic': 'Pag-vibrate na pahiwatig',

      // ── Step 6: Voice Persona ────────────────────────────────────────
      'voice_persona_title': 'Pumili ng boses',
      'voice_persona_subtitle': 'Anong tono ng boses ang pinaka-komportable at madaling pakinggan?',
      'voice_aria_desc': 'Isang malambot at nakapapawing-alinlangan na boses para gabayan ka.',
      'voice_max_desc': 'Isang malinaw at tiwala na boses na kapansin-pansin.',
      'voice_nova_desc': 'Isang aktibo at palakaibigang boses na puno ng sigla.',
      'voice_echo_desc': 'Isang malalim at malinaw na boses.',
      'voice_bella_desc': 'Isang mahinahon at mabagal na boses para matulungan kang mag-focus.',
      'voice_leo_desc': 'Isang masaya at makulay na batang boses.',

      // ── Step 7: Mobility Aids ────────────────────────────────────────
      'mobility_title': 'Mga kagamitan sa paglalakad',
      'mobility_subtitle': 'Gumagamit ka ba ng alinman sa mga ito para makatulong sa iyo sa paglalakad?',
      'mobility_white_cane': 'Puting Tungkod',
      'mobility_guide_dog': 'Aso ng Gabay',
      'mobility_smart_glasses': 'Smart Glasses',
      'mobility_eyeglasses': 'Salamin',
      'mobility_wheelchair': 'Wheelchair',
      'mobility_walker': 'Walker',
      'mobility_sighted_guide': 'Gabay na May Paningin',
      'mobility_none': 'Wala',

      // ── Step 8: Create Account ───────────────────────────────────────
      'create_account_title': 'Gumawa tayo ng account',
      'create_account_subtitle': 'Paano mo gustong mag-sign in?',
      'create_account_google': 'Google',
      'create_account_email': 'Email',

      // ── Step 9: Email Input ──────────────────────────────────────────
      'email_title': 'Ano ang iyong email address?',
      'email_subtitle': 'Gagamitin namin ito para sa mga mahahalagang update tungkol sa iyong account.',
      'email_hint': 'Ang iyong email address',
      'email_continue': 'Ituloy',
      'email_change_method': 'Gumamit ng ibang paraan',

      // ── Step 10: Phone Input ─────────────────────────────────────────
      'phone_title': 'Ano ang iyong numero ng telepono?',
      'phone_subtitle': 'Magpapadala kami ng isang beses na code para ma-verify na ikaw talaga ito.',
      'phone_hint': 'Ang iyong numero ng telepono',
      'phone_send_code': 'Magpadala ng code',
      'phone_change_method': 'Gumamit ng ibang paraan',

      // ── Step 10b: Verification Code ──────────────────────────────────
      'verify_title': 'Ilagay ang iyong code',
      'verify_subtitle': 'Pakiusap na ilagay ang 4-digit na code na ipinadala namin sa iyong telepono.',
      'verify_no_code': 'Hindi natanggap ang code?',
      'verify_resend': 'Ipadala ulit',
      'verify_confirm': 'Kumpirmahin',
      'verify_error_resend': 'Hindi namin mapadala ulit ang code. Pakisubukan ulit.',

      // ── Step 11: Create Password ─────────────────────────────────────
      'password_title': 'Pumili ng password',
      'password_subtitle': 'Pumili ng password na madali mong matandaan ngunit mahirap hulaan ng iba.',
      'password_enter': 'Ilagay ang password',
      'password_confirm_field': 'I-type ulit ang password',
      'password_keep_signed_in': 'Panatilihing naka-sign in',

      // ── Step 12: Permissions ─────────────────────────────────────────
      'permissions_title': 'I-enable ang mga feature',
      'permissions_subtitle': 'Para makapagsimula, kailangan namin ng ilang pahintulot para matulungan kang mag-navigate.',
      'permissions_camera': 'Camera (para makita ang iyong paligid)',
      'permissions_microphone': 'Mikropono (para marinig ang iyong mga utos)',
      'permissions_location': 'Lokasyon (para gabayan ka sa iyong ruta)',
      'permissions_bluetooth': 'Bluetooth (para kumonekta sa mga assistive device)',

      // ── Step 13: Terms & Privacy ─────────────────────────────────────
      'terms_title': 'Ang aming pangako sa iyo',
      'terms_agree': 'Sumasang-ayon ako',
      'terms_read': 'Basahin nang buo',
      'terms_body': 'Sa pagpapatuloy, sumasang-ayon ka sa aming mga tuntunin at patakaran sa privacy.',
      'terms_local_label': 'Lahat ay nananatili sa iyong telepono',
      'terms_local_body': 'Pinoproseso ng EasyLens ang iyong camera at mga detalye ng lokasyon direkta sa iyong device para mabilis at pribado ang iyong navigation.',
      'terms_privacy_label': 'Ang iyong privacy ang pinakamahalaga',
      'terms_privacy_body': 'Hindi namin inirerekord ang nakikita ng iyong camera, at pinapanatiling pribado at ligtas ang iyong impormasyon. Hindi namin ibinibenta ang iyong data.',

      // ── Step 14: Upload Photo ────────────────────────────────────────
      'photo_title': 'Magdagdag ng larawan',
      'photo_subtitle': 'Magdagdag ng larawan mo para makilala ka ng iyong mga kaibigan at tagtulong.',
      'photo_gallery': 'Pumili mula sa gallery',
      'photo_camera': 'Kumuha ng bagong larawan',
      'photo_choose': 'Pumili ng larawan',
      'photo_skip': 'Laktawan muna',

      // ── Step 15: Photo Confirmation ──────────────────────────────────
      'photo_confirm_title': 'Maganda!',
      'photo_confirm_subtitle': 'Ganito ang hitsura ng iyong profile picture.',
      'photo_confirm_reupload': 'Pumili ng ibang larawan',
      'photo_confirm_continue': 'Maganda, ituloy',

      // ── Step 16: Name Input ──────────────────────────────────────────
      'name_title': 'Ano ang tawag ko sa iyo?',
      'name_subtitle': 'I-tap ang mikropono para sabihin ang iyong pangalan, o i-type ito sa ibaba.',
      'name_mic_label': 'I-tap para sabihin ang iyong pangalan',
      'name_write_here': 'O isulat ito dito:',
      'name_hint': 'Ang iyong pangalan o palayaw',

      // ── Step 17: Birthday Input ──────────────────────────────────────
      'birthday_title': 'Kailan ang iyong kaarawan?',
      'birthday_subtitle': 'Maaari mong i-tap ang mikropono para sabihin ito, o isulat sa ibaba.',
      'birthday_mic_label': 'I-tap para sabihin ang iyong kaarawan',
      'birthday_calendar': 'O pumili mula sa kalendaryo:',

      // ── Step 18: SOS Contact ─────────────────────────────────────────
      'sos_title': 'Emergency contact',
      'sos_subtitle': 'Sino ang makikipag-ugnayan namin sa emergency? Magpapadala kami sa kanila ng alerto kung kailangan mo ng tulong.',
      'sos_import': 'Pumili mula sa contacts',
      'sos_or_manual': 'o isulat ang mga detalye sa ibaba',
      'sos_their_name': 'KANILANG BUONG PANGALAN',
      'sos_their_phone': 'KANILANG NUMERO NG TELEPONO',
      'sos_relationship': 'PAANO MO SYA KILALA? (HAL. KAPATID, KAIBIGAN)',
      'sos_finish': 'Tapusin ang pag-setup',

      // ── Units ────────────────────────────────────────────────────────
      'units_title': 'Mga sukat ng distansya',
      'units_subtitle': 'Paano mo gustong basahin ng app ang mga distansya?',
      'units_metric': 'Metriko',
      'units_imperial': 'Imperyal',

      // ── Validation Errors ────────────────────────────────────────────
      'error_email': 'Mangyaring maglagay ng wastong email address (hal. pangalan@halimbawa.com)',
      'error_phone': 'Mangyaring maglagay ng wastong 11-digit na numero ng telepono',
      'error_password_empty': 'Mangyaring gumawa ng password para sa iyong account',
      'error_password_short': 'Ang password ay dapat may hindi bababa sa 6 na karakter',
      'error_name': 'Mangyaring ilagay ang iyong pangalan o palayaw',
    },
  };

  /// Returns the localized string for [key].
  /// Falls back to English if the key is missing in the target language.
  /// Falls back to [key] itself if missing in English too.
  static String t(String key, String language) {
    final isFilipino = language.toLowerCase().contains('filipino') ||
        language.toLowerCase().contains('tagalog') ||
        language.toLowerCase().contains('fil');
    final langCode = isFilipino ? 'fil' : 'en';
    return _strings[langCode]?[key] ?? _strings['en']?[key] ?? key;
  }
}
