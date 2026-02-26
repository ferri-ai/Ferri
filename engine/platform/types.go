package platform

// PlatformRequest is sent from Go to Dart to request a native API call.
type PlatformRequest struct {
	RequestID string                 `json:"request_id"`
	ToolName  string                 `json:"tool_name"`
	Params    map[string]interface{} `json:"params"`
}

// PlatformResponse is sent back from Dart to Go to resolve a pending request.
type PlatformResponse struct {
	RequestID string `json:"request_id"`
	Success   bool   `json:"success"`
	Data      string `json:"data"`  // JSON string of the result
	Error     string `json:"error"` // Non-empty if success=false
}
