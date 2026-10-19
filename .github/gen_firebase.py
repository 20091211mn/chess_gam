# Generates lib/firebase_options_gen.dart from google-services.json (Android)
# or GoogleService-Info.plist (iOS, optional). Never fails the build.
import json, os, sys, plistlib

plat = sys.argv[1] if len(sys.argv) > 1 else 'android'
vals = None
try:
    if plat == 'ios' and os.path.exists('GoogleService-Info.plist'):
        p = plistlib.load(open('GoogleService-Info.plist', 'rb'))
        vals = dict(apiKey=p.get('API_KEY', ''), appId=p.get('GOOGLE_APP_ID', ''),
                    sender=str(p.get('GCM_SENDER_ID', '')), project=p.get('PROJECT_ID', ''),
                    bucket=p.get('STORAGE_BUCKET', ''), bundle=p.get('BUNDLE_ID', ''))
    elif os.path.exists('google-services.json'):
        j = json.load(open('google-services.json'))
        clients = j.get('client', [])
        c = None
        for x in clients:
            if x.get('client_info', {}).get('android_client_info', {}).get('package_name') == 'com.shatranj.chess_game':
                c = x
        if c is None and clients:
            c = clients[0]
        if c is not None:
            vals = dict(apiKey=c['api_key'][0]['current_key'],
                        appId=c['client_info']['mobilesdk_app_id'],
                        sender=str(j['project_info']['project_number']),
                        project=j['project_info']['project_id'],
                        bucket=j['project_info'].get('storage_bucket', ''), bundle='')
except Exception as e:
    print('could not read firebase config:', e)
    vals = None

if vals:
    bundle = "\n  iosBundleId: '%s'," % vals['bundle'] if vals.get('bundle') else ''
    src = """import 'package:firebase_core/firebase_core.dart';

const bool firebaseConfigured = true;
const FirebaseOptions firebaseOptions = FirebaseOptions(
  apiKey: '%s',
  appId: '%s',
  messagingSenderId: '%s',
  projectId: '%s',
  storageBucket: '%s',%s
);
""" % (vals['apiKey'], vals['appId'], vals['sender'], vals['project'], vals['bucket'], bundle)
    open('lib/firebase_options_gen.dart', 'w').write(src)
    print('Firebase CONFIGURED for project', vals['project'])
else:
    print('Firebase NOT configured (google-services.json not found) - online will be disabled')
