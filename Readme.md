# Shoutbox
Example plugin for the [Auth API](https://openplanet.dev/docs/api/Auth).

You can find the source code for [the backend of the shoutbox on Github](https://github.com/openplanet-nl/shoutbox-server) as well.

## Basic example
The following is the most basic example for getting a token to validate with the Openplanet.dev backend API.

```angelscript
// Start the task to get the token from Openplanet
auto tokenTask = Auth::GetToken();

// Wait until the task has finished
while (!tokenTask.Finished()) {
	yield();
}

// Get the token
string token = tokenTask.Token();

// Send the token to our server
// ...
```
