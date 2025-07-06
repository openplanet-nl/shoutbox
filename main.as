[Setting name="Server URL"]
string Setting_ServerURL = "https://shoutbox.openplanet.dev";

string g_accountID = "";
string g_displayName = "";
string g_secret = "";

class Message
{
	string m_accountID;
	string m_displayName;
	string m_message;
	string m_time;
}

bool g_visible = false;
string g_messageInput = "";
array<Message@> g_messages;

void RenderMenu()
{
	if (UI::MenuItem("\\$4f4" + Icons::Wifi + "\\$z Shoutbox", "", g_visible)) {
		g_visible = !g_visible;
	}
}

void RenderInterface()
{
	if (!g_visible) {
		return;
	}

	UI::SetNextWindowSize(400, 300);
	if (UI::Begin("\\$4f4" + Icons::Wifi + "\\$z Shoutbox##Shoutbox", g_visible)) {
		RenderMainWindow();
	}
	UI::End();
}

void RenderMainWindow()
{
	if (g_secret == "") {
		UI::Text("Authenticating...");
	} else {
		UI::Text(g_displayName + " (" + g_accountID + ")");

		bool pressedEnter = false;
		g_messageInput = UI::InputText("Text", g_messageInput, pressedEnter, UI::InputTextFlags::EnterReturnsTrue);
		if (pressedEnter) {
			startnew(SendMessageAsync);
		}

		for (uint i = 0; i < g_messages.Length; i++) {
			auto msg = g_messages[i];
			UI::Text("\\$4f4" + Icons::User + " \\$666" + msg.m_displayName + "\\$z " + msg.m_message);
		}
	}
}

void Main()
{
	while (true) {
		if (g_visible) {
			if (g_secret != "") {
				ListAsync();
				sleep(1000);
			} else {
				if (!AuthAppAsync()) {
					g_visible = false;
				}
			}
		}
		yield();
	}
}

void ListAsync()
{
	auto req = Net::HttpRequest();
	req.Method = Net::HttpMethod::Get;
	req.Url = Setting_ServerURL + "/list";
	req.Start();

	while (!req.Finished()) {
		yield();
	}
	if (req.ResponseCode() != 200) {
		error("Server returned an error! (" + req.ResponseCode() + ") " + req.String());
		g_visible = false;
		return;
	}

	auto js = Json::Parse(req.String());
	auto jsArr = js["items"];

	g_messages.RemoveRange(0, g_messages.Length);
	for (uint i = 0; i < jsArr.Length; i++) {
		auto jsMsg = jsArr[i];
		auto newMessage = Message();
		newMessage.m_accountID = jsMsg["account_id"];
		newMessage.m_displayName = jsMsg["display_name"];
		newMessage.m_message = jsMsg["message"];
		newMessage.m_time = jsMsg["time"];
		g_messages.InsertLast(newMessage);
	}
}

void SendMessageAsync()
{
	string msg = g_messageInput;
	g_messageInput = "";

	auto req = Net::HttpRequest();
	req.Method = Net::HttpMethod::Post;
	req.Url = Setting_ServerURL + "/send";
	req.Headers["Authorization"] = "Secret " + g_secret;
	req.Body = "message=" + Net::UrlEncode(msg);
	await(req.Start());
}

bool AuthAppAsync()
{
	// Start the task to get the token from Openplanet
	auto tokenTask = Auth::GetToken();

	// Wait until the task has finished
	while (!tokenTask.Finished()) {
		yield();
	}

	// Take the token
	string token = tokenTask.Token();
	trace("Token: \"" + token + "\"");

	// Send it to the shoutbox server
	auto req = Net::HttpPost(
		Setting_ServerURL + "/auth",
		"t=" + Net::UrlEncode(token)
	);
	while (!req.Finished()) {
		yield();
	}
	if (req.ResponseCode() != 200) {
		error("Unable to authenticate, http error " + req.ResponseCode());
		return false;
	}

	// Parse the server response
	auto js = Json::Parse(req.String());

	// Check for any errors
	if (js.HasKey("error")) {
		string err = js["error"];
		error("Unable to authenticate: " + err);
		return false;
	}

	// Keep track of our information, including a secret that we can use to authenticate ourselves with the shoutbox server
	g_accountID = js["account_id"];
	g_displayName = js["display_name"];
	g_secret = js["secret"];

	return true;
}
