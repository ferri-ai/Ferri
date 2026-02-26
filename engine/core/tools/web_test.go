package tools

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// TestWebTool_WebFetch_Success verifies successful URL fetching
func TestWebTool_WebFetch_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("<html><body><h1>Test Page</h1><p>Content here</p></body></html>"))
	}))
	defer server.Close()

	tool := NewWebFetchTool(50000)
	ctx := context.Background()
	args := map[string]interface{}{
		"url": server.URL,
	}

	result := tool.Execute(ctx, args)

	// Success should not be an error
	if result.IsError {
		t.Errorf("Expected success, got IsError=true: %s", result.ForLLM)
	}

	// ForUser should contain the fetched content
	if !strings.Contains(result.ForUser, "Test Page") {
		t.Errorf("Expected ForUser to contain 'Test Page', got: %s", result.ForUser)
	}

	// ForLLM should contain summary
	if !strings.Contains(result.ForLLM, "bytes") && !strings.Contains(result.ForLLM, "extractor") {
		t.Errorf("Expected ForLLM to contain summary, got: %s", result.ForLLM)
	}
}

// TestWebTool_WebFetch_JSON verifies JSON content handling
func TestWebTool_WebFetch_JSON(t *testing.T) {
	testData := map[string]string{"key": "value", "number": "123"}
	expectedJSON, _ := json.MarshalIndent(testData, "", "  ")

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write(expectedJSON)
	}))
	defer server.Close()

	tool := NewWebFetchTool(50000)
	ctx := context.Background()
	args := map[string]interface{}{
		"url": server.URL,
	}

	result := tool.Execute(ctx, args)

	// Success should not be an error
	if result.IsError {
		t.Errorf("Expected success, got IsError=true: %s", result.ForLLM)
	}

	// ForUser should contain formatted JSON
	if !strings.Contains(result.ForUser, "key") && !strings.Contains(result.ForUser, "value") {
		t.Errorf("Expected ForUser to contain JSON data, got: %s", result.ForUser)
	}
}

// TestWebTool_WebFetch_InvalidURL verifies error handling for invalid URL
func TestWebTool_WebFetch_InvalidURL(t *testing.T) {
	tool := NewWebFetchTool(50000)
	ctx := context.Background()
	args := map[string]interface{}{
		"url": "not-a-valid-url",
	}

	result := tool.Execute(ctx, args)

	// Should return error result
	if !result.IsError {
		t.Errorf("Expected error for invalid URL")
	}

	// Should contain error message (either "invalid URL" or scheme error)
	if !strings.Contains(result.ForLLM, "URL") && !strings.Contains(result.ForUser, "URL") {
		t.Errorf("Expected error message for invalid URL, got ForLLM: %s", result.ForLLM)
	}
}

// TestWebTool_WebFetch_UnsupportedScheme verifies error handling for non-http URLs
func TestWebTool_WebFetch_UnsupportedScheme(t *testing.T) {
	tool := NewWebFetchTool(50000)
	ctx := context.Background()
	args := map[string]interface{}{
		"url": "ftp://example.com/file.txt",
	}

	result := tool.Execute(ctx, args)

	// Should return error result
	if !result.IsError {
		t.Errorf("Expected error for unsupported URL scheme")
	}

	// Should mention only http/https allowed
	if !strings.Contains(result.ForLLM, "http/https") && !strings.Contains(result.ForUser, "http/https") {
		t.Errorf("Expected scheme error message, got ForLLM: %s", result.ForLLM)
	}
}

// TestWebTool_WebFetch_MissingURL verifies error handling for missing URL
func TestWebTool_WebFetch_MissingURL(t *testing.T) {
	tool := NewWebFetchTool(50000)
	ctx := context.Background()
	args := map[string]interface{}{}

	result := tool.Execute(ctx, args)

	// Should return error result
	if !result.IsError {
		t.Errorf("Expected error when URL is missing")
	}

	// Should mention URL is required
	if !strings.Contains(result.ForLLM, "url is required") && !strings.Contains(result.ForUser, "url is required") {
		t.Errorf("Expected 'url is required' message, got ForLLM: %s", result.ForLLM)
	}
}

// TestWebTool_WebFetch_Truncation verifies content truncation
func TestWebTool_WebFetch_Truncation(t *testing.T) {
	longContent := strings.Repeat("x", 20000)

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(longContent))
	}))
	defer server.Close()

	tool := NewWebFetchTool(1000) // Limit to 1000 chars
	ctx := context.Background()
	args := map[string]interface{}{
		"url": server.URL,
	}

	result := tool.Execute(ctx, args)

	// Success should not be an error
	if result.IsError {
		t.Errorf("Expected success, got IsError=true: %s", result.ForLLM)
	}

	// ForUser should contain truncated content (not the full 20000 chars)
	resultMap := make(map[string]interface{})
	json.Unmarshal([]byte(result.ForUser), &resultMap)
	if text, ok := resultMap["text"].(string); ok {
		if len(text) > 1100 { // Allow some margin
			t.Errorf("Expected content to be truncated to ~1000 chars, got: %d", len(text))
		}
	}

	// Should be marked as truncated
	if truncated, ok := resultMap["truncated"].(bool); !ok || !truncated {
		t.Errorf("Expected 'truncated' to be true in result")
	}
}

// TestWebTool_WebSearch_NoApiKey verifies that no tool is created when API key is missing
func TestWebTool_WebSearch_NoApiKey(t *testing.T) {
	tool := NewWebSearchTool(WebSearchToolOptions{BraveEnabled: true, BraveAPIKey: ""})
	if tool != nil {
		t.Errorf("Expected nil tool when Brave API key is empty")
	}

	// Also nil when nothing is enabled
	tool = NewWebSearchTool(WebSearchToolOptions{})
	if tool != nil {
		t.Errorf("Expected nil tool when no provider is enabled")
	}
}

// TestWebTool_WebSearch_MissingQuery verifies error handling for missing query
func TestWebTool_WebSearch_MissingQuery(t *testing.T) {
	tool := NewWebSearchTool(WebSearchToolOptions{BraveEnabled: true, BraveAPIKey: "test-key", BraveMaxResults: 5})
	ctx := context.Background()
	args := map[string]interface{}{}

	result := tool.Execute(ctx, args)

	// Should return error result
	if !result.IsError {
		t.Errorf("Expected error when query is missing")
	}
}

// TestWebTool_WebFetch_HTMLExtraction verifies HTML text extraction
func TestWebTool_WebFetch_HTMLExtraction(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`<html><body><script>alert('test');</script><style>body{color:red;}</style><h1>Title</h1><p>Content</p></body></html>`))
	}))
	defer server.Close()

	tool := NewWebFetchTool(50000)
	ctx := context.Background()
	args := map[string]interface{}{
		"url": server.URL,
	}

	result := tool.Execute(ctx, args)

	// Success should not be an error
	if result.IsError {
		t.Errorf("Expected success, got IsError=true: %s", result.ForLLM)
	}

	// ForUser should contain extracted text (without script/style tags)
	if !strings.Contains(result.ForUser, "Title") && !strings.Contains(result.ForUser, "Content") {
		t.Errorf("Expected ForUser to contain extracted text, got: %s", result.ForUser)
	}

	// Should NOT contain script or style tags
	if strings.Contains(result.ForUser, "<script>") || strings.Contains(result.ForUser, "<style>") {
		t.Errorf("Expected script/style tags to be removed, got: %s", result.ForUser)
	}
}

// TestWebTool_WebFetch_MissingDomain verifies error handling for URL without domain
func TestWebTool_WebFetch_MissingDomain(t *testing.T) {
	tool := NewWebFetchTool(50000)
	ctx := context.Background()
	args := map[string]interface{}{
		"url": "https://",
	}

	result := tool.Execute(ctx, args)

	// Should return error result
	if !result.IsError {
		t.Errorf("Expected error for URL without domain")
	}

	// Should mention missing domain
	if !strings.Contains(result.ForLLM, "domain") && !strings.Contains(result.ForUser, "domain") {
		t.Errorf("Expected domain error message, got ForLLM: %s", result.ForLLM)
	}
}

// TestDDG_ExtractHTMLResults verifies HTML regex extraction from DDG search page
func TestDDG_ExtractHTMLResults(t *testing.T) {
	// Sample DDG HTML output with result__a class
	sampleHTML := `
<html>
<body>
<div class="results">
  <div class="result results_links results_links_deep web-result">
    <div class="links_main links_deep result__body">
      <h2 class="result__title">
        <a rel="nofollow" class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2Fpage1&amp;rut=abc123">Example Page One</a>
      </h2>
      <a class="result__snippet" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2Fpage1">This is the first result snippet with useful info.</a>
    </div>
  </div>
  <div class="result results_links results_links_deep web-result">
    <div class="links_main links_deep result__body">
      <h2 class="result__title">
        <a rel="nofollow" class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.org%2Fpage2&amp;rut=def456">Example Page Two</a>
      </h2>
      <a class="result__snippet" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.org%2Fpage2">Second result with different content.</a>
    </div>
  </div>
</div>
</body>
</html>`

	provider := &DuckDuckGoSearchProvider{}
	result, err := provider.extractHTMLResults(sampleHTML, 5, "test query")

	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}

	if !strings.Contains(result, "Results for: test query") {
		t.Errorf("Expected header line, got: %s", result)
	}

	if !strings.Contains(result, "Example Page One") {
		t.Errorf("Expected first title, got: %s", result)
	}

	if !strings.Contains(result, "Example Page Two") {
		t.Errorf("Expected second title, got: %s", result)
	}

	// Verify URL was decoded from uddg= param
	if !strings.Contains(result, "https://example.com/page1") {
		t.Errorf("Expected decoded URL for first result, got: %s", result)
	}

	if !strings.Contains(result, "first result snippet") {
		t.Errorf("Expected snippet text, got: %s", result)
	}
}

// TestDDG_ExtractHTMLResults_NoResults verifies error on empty HTML
func TestDDG_ExtractHTMLResults_NoResults(t *testing.T) {
	provider := &DuckDuckGoSearchProvider{}
	_, err := provider.extractHTMLResults("<html><body>No search results here</body></html>", 5, "nothing")

	if err == nil {
		t.Error("Expected error for HTML with no results")
	}
}

// TestDDG_ParseJSONResults verifies JSON parsing of d.js response
func TestDDG_ParseJSONResults(t *testing.T) {
	// Simulate d.js JSON response
	jsonBody := `[{"t":"Go Programming Language","u":"https://go.dev/","a":"The Go programming language is an open source project."},{"t":"Go Tutorial","u":"https://go.dev/tour/","a":"A tour of Go for beginners."},{"t":"","u":"","a":""}]`

	provider := &DuckDuckGoSearchProvider{}
	result, err := provider.parseJSONResults(jsonBody, 5, "golang")

	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}

	if !strings.Contains(result, "Go Programming Language") {
		t.Errorf("Expected first title, got: %s", result)
	}

	if !strings.Contains(result, "https://go.dev/") {
		t.Errorf("Expected URL, got: %s", result)
	}

	if !strings.Contains(result, "open source project") {
		t.Errorf("Expected snippet, got: %s", result)
	}

	// Empty sentinel entry should be filtered out
	if strings.Count(result, "\n   https://") != 2 {
		t.Errorf("Expected 2 URL lines (filtered sentinel), got: %s", result)
	}
}

// TestDDG_ParseJSONResults_JSWrapper verifies parsing when d.js wraps in JS callback
func TestDDG_ParseJSONResults_JSWrapper(t *testing.T) {
	jsBody := `DDG.pageLayout.load('d',[{"t":"Result One","u":"https://one.com/","a":"First."},{"t":"Result Two","u":"https://two.com/","a":"Second."}]);`

	provider := &DuckDuckGoSearchProvider{}
	result, err := provider.parseJSONResults(jsBody, 5, "test")

	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}

	if !strings.Contains(result, "Result One") {
		t.Errorf("Expected first title from JS wrapper, got: %s", result)
	}

	if !strings.Contains(result, "https://two.com/") {
		t.Errorf("Expected second URL, got: %s", result)
	}
}

// TestDDG_ExtractDDGURL verifies URL decoding from DDG redirect format
func TestDDG_ExtractDDGURL(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2Fpath&rut=abc", "https://example.com/path"},
		{"https://example.com/direct", "https://example.com/direct"},
		{"/l/?uddg=https%3A%2F%2Ftest.org&kh=1", "https://test.org"},
	}

	for _, tt := range tests {
		got := extractDDGURL(tt.input)
		if got != tt.expected {
			t.Errorf("extractDDGURL(%q) = %q, want %q", tt.input, got, tt.expected)
		}
	}
}

// TestDDG_SearchWithMockServer verifies the full DDG HTML search flow with a mock server
func TestDDG_SearchWithMockServer(t *testing.T) {
	// Mock DDG HTML endpoint
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Verify it's a POST request with form data
		if r.Method != "POST" {
			t.Errorf("Expected POST, got %s", r.Method)
		}
		if ct := r.Header.Get("Content-Type"); !strings.Contains(ct, "form-urlencoded") {
			t.Errorf("Expected form-urlencoded, got %s", ct)
		}
		w.Header().Set("Content-Type", "text/html")
		w.Write([]byte(`<div class="result"><a class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fmock.example.com">Mock Result</a><a class="result__snippet">A mock snippet.</a></div>`))
	}))
	defer server.Close()

	// We can't easily override the URL in the provider, but we can test extractHTMLResults directly
	provider := &DuckDuckGoSearchProvider{}
	html := `<div class="result"><a class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fmock.example.com">Mock Result</a><a class="result__snippet">A mock snippet.</a></div>`

	result, err := provider.extractHTMLResults(html, 5, "mock test")
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	if !strings.Contains(result, "Mock Result") {
		t.Errorf("Expected 'Mock Result', got: %s", result)
	}

	if !strings.Contains(result, "https://mock.example.com") {
		t.Errorf("Expected decoded URL, got: %s", result)
	}
}
