// Fetches the latest OTP email from MailSlurp and exposes the 5-digit code as output.otp
//
// Env vars:
//   MAILSLURP_API_KEY  (required)
//   MAILSLURP_INBOX_ID (optional; if empty, looked up from EMAIL)
//   EMAIL              (needed only when MAILSLURP_INBOX_ID is empty)
//   OTP_SINCE          (optional ISO timestamp; ignore older emails)
//   OTP_TIMEOUT_MS     (optional, default 60000)

var BASE = 'https://api.mailslurp.com';
var headers = { 'x-api-key': MAILSLURP_API_KEY, 'Accept': 'application/json' };

function get(path) {
  var res = http.get(BASE + path, { headers: headers });
  if (!res.ok) {
    throw new Error('MailSlurp ' + path + ' failed: ' + res.status + ' ' + res.body);
  }
  return json(res.body);
}

var inboxId = (typeof MAILSLURP_INBOX_ID !== 'undefined' && MAILSLURP_INBOX_ID)
  ? MAILSLURP_INBOX_ID
  : get('/inboxes/byEmailAddress?emailAddress=' + encodeURIComponent(EMAIL)).inboxId;

if (!inboxId) throw new Error('Could not resolve MailSlurp inbox for ' + EMAIL);

var timeout = (typeof OTP_TIMEOUT_MS !== 'undefined' && OTP_TIMEOUT_MS) ? OTP_TIMEOUT_MS : 60000;
var qs = '?inboxId=' + inboxId + '&timeout=' + timeout + '&unreadOnly=true';
if (typeof OTP_SINCE !== 'undefined' && OTP_SINCE) {
  qs += '&since=' + encodeURIComponent(OTP_SINCE);
}
var email = get('/waitForLatestEmail' + qs);

// Strip HTML so CSS/hex values don't produce false matches
var text = (email.body || '')
  .replace(/<style[\s\S]*?<\/style>/gi, ' ')
  .replace(/<[^>]+>/g, ' ')
  .replace(/&nbsp;/g, ' ');

var match = text.match(/(?:^|\D)(\d{5})(?:\D|$)/);
if (!match) {
  throw new Error('No 5-digit OTP found in email "' + email.subject + '": ' + text.substring(0, 200));
}

output.otp = match[1];
console.log('OTP retrieved: ' + output.otp);
