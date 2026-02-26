package tools

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"
)

const (
	// Desktop UA for web_fetch (general browsing)
	userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
	// Mobile UA for DDG search (matches Android device)
	ddgUserAgent = "Mozilla/5.0 (Linux; Android 14; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36"
)

type SearchProvider interface {
	Search(ctx context.Context, query string, count int) (string, error)
}

type BraveSearchProvider struct {
	apiKey string
}

func (p *BraveSearchProvider) Search(ctx context.Context, query string, count int) (string, error) {
	searchURL := fmt.Sprintf("https://api.search.brave.com/res/v1/web/search?q=%s&count=%d",
		url.QueryEscape(query), count)

	req, err := http.NewRequestWithContext(ctx, "GET", searchURL, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Accept", "application/json")
	req.Header.Set("X-Subscription-Token", p.apiKey)

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	var searchResp struct {
		Web struct {
			Results []struct {
				Title       string `json:"title"`
				URL         string `json:"url"`
				Description string `json:"description"`
			} `json:"results"`
		} `json:"web"`
	}

	if err := json.Unmarshal(body, &searchResp); err != nil {
		return "", fmt.Errorf("failed to parse response: %w", err)
	}

	results := searchResp.Web.Results
	if len(results) == 0 {
		return fmt.Sprintf("No results for: %s", query), nil
	}

	var lines []string
	lines = append(lines, fmt.Sprintf("Results for: %s", query))
	for i, item := range results {
		if i >= count {
			break
		}
		lines = append(lines, fmt.Sprintf("%d. %s\n   %s", i+1, item.Title, item.URL))
		if item.Description != "" {
			lines = append(lines, fmt.Sprintf("   %s", item.Description))
		}
	}

	return strings.Join(lines, "\n"), nil
}

type DuckDuckGoSearchProvider struct{}

// ddgClient returns an http.Client configured for DDG requests with modern TLS.
func ddgClient(timeout time.Duration) *http.Client {
	return &http.Client{
		Timeout: timeout,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				MinVersion: tls.VersionTLS12,
			},
			TLSHandshakeTimeout: 10 * time.Second,
			DisableCompression:  false,
		},
	}
}

// setDDGHeaders adds browser-like headers to a DDG request.
func setDDGHeaders(req *http.Request) {
	req.Header.Set("User-Agent", ddgUserAgent)
	req.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
	req.Header.Set("Accept-Language", "en-US,en;q=0.9")
	req.Header.Set("Referer", "https://duckduckgo.com/")
}

func (p *DuckDuckGoSearchProvider) Search(ctx context.Context, query string, count int) (string, error) {
	log.Printf("[DDG] searching: q=%q count=%d", query, count)

	// Strategy: try DDG's JSON API first (structured data, no regex).
	// Fall back to HTML scraping if JSON API fails.
	result, err := p.searchJSON(ctx, query, count)
	if err == nil {
		return result, nil
	}
	log.Printf("[DDG] JSON API failed: %v — falling back to HTML", err)

	result, err = p.searchHTML(ctx, query, count)
	if err != nil {
		log.Printf("[DDG] HTML scrape also failed: %v", err)
		return "", fmt.Errorf("DuckDuckGo search failed (tried JSON API and HTML scrape): %w", err)
	}
	return result, nil
}

// searchJSON uses DDG's internal JSON API (links.duckduckgo.com/d.js).
// Step 1: POST to duckduckgo.com to get a vqd token.
// Step 2: GET d.js with the token for JSON results.
func (p *DuckDuckGoSearchProvider) searchJSON(ctx context.Context, query string, count int) (string, error) {
	client := ddgClient(15 * time.Second)

	// Step 1: Get vqd token
	vqd, err := p.getVQDToken(ctx, client, query)
	if err != nil {
		return "", fmt.Errorf("vqd token: %w", err)
	}
	log.Printf("[DDG] got vqd token: %s", vqd[:min(len(vqd), 16)]+"...")

	// Step 2: Fetch JSON results
	jsURL := fmt.Sprintf("https://links.duckduckgo.com/d.js?q=%s&vqd=%s&kl=wt-wt&l=wt-wt&o=json&s=0&ex=-1",
		url.QueryEscape(query), url.QueryEscape(vqd))

	req, err := http.NewRequestWithContext(ctx, "GET", jsURL, nil)
	if err != nil {
		return "", fmt.Errorf("create d.js request: %w", err)
	}
	setDDGHeaders(req)
	req.Header.Set("Referer", "https://duckduckgo.com/")

	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("d.js request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("d.js read: %w", err)
	}
	log.Printf("[DDG] d.js response: status=%d bodyLen=%d", resp.StatusCode, len(body))

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("d.js status %d", resp.StatusCode)
	}

	return p.parseJSONResults(string(body), count, query)
}

// getVQDToken fetches the vqd token required for DDG's JSON API.
func (p *DuckDuckGoSearchProvider) getVQDToken(ctx context.Context, client *http.Client, query string) (string, error) {
	formData := url.Values{"q": {query}}
	req, err := http.NewRequestWithContext(ctx, "POST", "https://duckduckgo.com/", strings.NewReader(formData.Encode()))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	setDDGHeaders(req)

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	// Extract vqd token from response body
	// Pattern: vqd="<token>" or vqd='<token>' or vqd=<token>&
	re := regexp.MustCompile(`vqd=['"]?([^'"&]+)`)
	match := re.FindSubmatch(body)
	if match == nil {
		return "", fmt.Errorf("vqd token not found in response (%d bytes)", len(body))
	}
	return string(match[1]), nil
}

// parseJSONResults parses the d.js JSON response into formatted text.
func (p *DuckDuckGoSearchProvider) parseJSONResults(body string, count int, query string) (string, error) {
	// d.js wraps results in: DDG.pageLayout.load('d',[{...results...}]);
	// Or it may return raw JSON array. Try both.
	jsonStr := body

	// Strip JS wrapper if present
	if idx := strings.Index(body, "[{"); idx != -1 {
		endIdx := strings.LastIndex(body, "}]")
		if endIdx != -1 && endIdx > idx {
			jsonStr = body[idx : endIdx+2]
		}
	}

	var results []struct {
		Title   string `json:"t"`
		URL     string `json:"u"`
		Snippet string `json:"a"`
	}

	if err := json.Unmarshal([]byte(jsonStr), &results); err != nil {
		return "", fmt.Errorf("parse d.js JSON: %w (body prefix: %s)", err, body[:min(len(body), 200)])
	}

	// Filter out empty/marker entries (DDG includes sentinel objects)
	var filtered []struct {
		Title   string `json:"t"`
		URL     string `json:"u"`
		Snippet string `json:"a"`
	}
	for _, r := range results {
		if r.URL != "" && r.Title != "" {
			filtered = append(filtered, r)
		}
	}

	if len(filtered) == 0 {
		return fmt.Sprintf("No results for: %s", query), nil
	}

	var lines []string
	lines = append(lines, fmt.Sprintf("Results for: %s (via DuckDuckGo)", query))

	maxItems := min(len(filtered), count)
	for i := 0; i < maxItems; i++ {
		r := filtered[i]
		title := stripTags(r.Title)
		snippet := stripTags(r.Snippet)
		lines = append(lines, fmt.Sprintf("%d. %s\n   %s", i+1, title, r.URL))
		if snippet != "" {
			lines = append(lines, fmt.Sprintf("   %s", snippet))
		}
	}

	return strings.Join(lines, "\n"), nil
}

// searchHTML falls back to HTML scraping of duckduckgo.com/html/.
func (p *DuckDuckGoSearchProvider) searchHTML(ctx context.Context, query string, count int) (string, error) {
	// Use POST with form data (how browsers submit to DDG)
	formData := url.Values{"q": {query}, "b": {""}}
	req, err := http.NewRequestWithContext(ctx, "POST", "https://duckduckgo.com/html/",
		strings.NewReader(formData.Encode()))
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	setDDGHeaders(req)

	client := ddgClient(15 * time.Second)
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	log.Printf("[DDG] HTML response: status=%d bodyLen=%d", resp.StatusCode, len(body))

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("DDG returned status %d", resp.StatusCode)
	}

	return p.extractHTMLResults(string(body), count, query)
}

func (p *DuckDuckGoSearchProvider) extractHTMLResults(html string, count int, query string) (string, error) {
	// Try multiple regex patterns for robustness — DDG may change class names.
	// Pattern 1: Standard result__a class (current DDG HTML)
	reLink := regexp.MustCompile(`<a[^>]*class="[^"]*result__a[^"]*"[^>]*href="([^"]+)"[^>]*>([\s\S]*?)</a>`)
	matches := reLink.FindAllStringSubmatch(html, count+5)

	// Pattern 2: Fallback — any link inside a result div
	if len(matches) == 0 {
		reLink = regexp.MustCompile(`<div[^>]*class="[^"]*result[^"]*"[^>]*>[\s\S]*?<a[^>]*href="([^"]+)"[^>]*>([\s\S]*?)</a>`)
		matches = reLink.FindAllStringSubmatch(html, count+5)
	}

	if len(matches) == 0 {
		// Log a prefix of HTML for debugging
		preview := html
		if len(preview) > 500 {
			preview = preview[:500]
		}
		log.Printf("[DDG] no results matched in HTML (len=%d, preview=%s)", len(html), preview)
		return "", fmt.Errorf("no results found in HTML response (%d bytes)", len(html))
	}

	var lines []string
	lines = append(lines, fmt.Sprintf("Results for: %s (via DuckDuckGo)", query))

	reSnippet := regexp.MustCompile(`<a class="result__snippet[^"]*"[^>]*>([\s\S]*?)</a>`)
	snippetMatches := reSnippet.FindAllStringSubmatch(html, count+5)

	// Fallback snippet pattern
	if len(snippetMatches) == 0 {
		reSnippet = regexp.MustCompile(`<span[^>]*class="[^"]*result__snippet[^"]*"[^>]*>([\s\S]*?)</span>`)
		snippetMatches = reSnippet.FindAllStringSubmatch(html, count+5)
	}

	maxItems := min(len(matches), count)

	for i := 0; i < maxItems; i++ {
		urlStr := matches[i][1]
		title := stripTags(matches[i][2])
		title = strings.TrimSpace(title)

		// DDG wraps real URLs in a redirect: /l/?uddg=<encoded_url>&...
		urlStr = extractDDGURL(urlStr)

		lines = append(lines, fmt.Sprintf("%d. %s\n   %s", i+1, title, urlStr))

		if i < len(snippetMatches) {
			snippet := stripTags(snippetMatches[i][1])
			snippet = strings.TrimSpace(snippet)
			if snippet != "" {
				lines = append(lines, fmt.Sprintf("   %s", snippet))
			}
		}
	}

	return strings.Join(lines, "\n"), nil
}

// extractDDGURL decodes DDG's redirect URL to get the real destination.
func extractDDGURL(rawURL string) string {
	// DDG wraps URLs as: //duckduckgo.com/l/?uddg=<url_encoded>&rut=...
	if strings.Contains(rawURL, "uddg=") {
		decoded, err := url.QueryUnescape(rawURL)
		if err == nil {
			rawURL = decoded
		}
		if idx := strings.Index(rawURL, "uddg="); idx != -1 {
			rest := rawURL[idx+5:]
			// Trim any trailing params after &
			if amp := strings.Index(rest, "&"); amp != -1 {
				rest = rest[:amp]
			}
			return rest
		}
	}
	return rawURL
}

func stripTags(content string) string {
	re := regexp.MustCompile(`<[^>]+>`)
	return re.ReplaceAllString(content, "")
}

type PerplexitySearchProvider struct {
	apiKey string
}

func (p *PerplexitySearchProvider) Search(ctx context.Context, query string, count int) (string, error) {
	searchURL := "https://api.perplexity.ai/chat/completions"

	payload := map[string]interface{}{
		"model": "sonar",
		"messages": []map[string]string{
			{"role": "system", "content": "You are a search assistant. Provide concise search results with titles, URLs, and brief descriptions in the following format:\n1. Title\n   URL\n   Description\n\nDo not add extra commentary."},
			{"role": "user", "content": fmt.Sprintf("Search for: %s. Provide up to %d relevant results.", query, count)},
		},
		"max_tokens": 1000,
	}

	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", searchURL, strings.NewReader(string(payloadBytes)))
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+p.apiKey)
	req.Header.Set("User-Agent", userAgent)

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("Perplexity API error: %s", string(body))
	}

	var searchResp struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}

	if err := json.Unmarshal(body, &searchResp); err != nil {
		return "", fmt.Errorf("failed to parse response: %w", err)
	}

	if len(searchResp.Choices) == 0 {
		return fmt.Sprintf("No results for: %s", query), nil
	}

	return fmt.Sprintf("Results for: %s (via Perplexity)\n%s", query, searchResp.Choices[0].Message.Content), nil
}

type WebSearchTool struct {
	provider   SearchProvider
	maxResults int
}

type WebSearchToolOptions struct {
	BraveAPIKey          string
	BraveMaxResults      int
	BraveEnabled         bool
	DuckDuckGoMaxResults int
	DuckDuckGoEnabled    bool
	PerplexityAPIKey     string
	PerplexityMaxResults int
	PerplexityEnabled    bool
}

func NewWebSearchTool(opts WebSearchToolOptions) *WebSearchTool {
	var provider SearchProvider
	maxResults := 5

	// Priority: Perplexity > Brave > DuckDuckGo
	if opts.PerplexityEnabled && opts.PerplexityAPIKey != "" {
		provider = &PerplexitySearchProvider{apiKey: opts.PerplexityAPIKey}
		if opts.PerplexityMaxResults > 0 {
			maxResults = opts.PerplexityMaxResults
		}
	} else if opts.BraveEnabled && opts.BraveAPIKey != "" {
		provider = &BraveSearchProvider{apiKey: opts.BraveAPIKey}
		if opts.BraveMaxResults > 0 {
			maxResults = opts.BraveMaxResults
		}
	} else if opts.DuckDuckGoEnabled {
		provider = &DuckDuckGoSearchProvider{}
		if opts.DuckDuckGoMaxResults > 0 {
			maxResults = opts.DuckDuckGoMaxResults
		}
	} else {
		return nil
	}

	return &WebSearchTool{
		provider:   provider,
		maxResults: maxResults,
	}
}

func (t *WebSearchTool) Name() string {
	return "web_search"
}

func (t *WebSearchTool) Description() string {
	return "Search the web for current information. Returns titles, URLs, and snippets from search results."
}

func (t *WebSearchTool) Parameters() map[string]interface{} {
	return map[string]interface{}{
		"type": "object",
		"properties": map[string]interface{}{
			"query": map[string]interface{}{
				"type":        "string",
				"description": "Search query",
			},
			"count": map[string]interface{}{
				"type":        "integer",
				"description": "Number of results (1-10)",
				"minimum":     1.0,
				"maximum":     10.0,
			},
		},
		"required": []string{"query"},
	}
}

func (t *WebSearchTool) Execute(ctx context.Context, args map[string]interface{}) *ToolResult {
	query, ok := args["query"].(string)
	if !ok {
		return ErrorResult("query is required")
	}

	count := t.maxResults
	if c, ok := args["count"].(float64); ok {
		if int(c) > 0 && int(c) <= 10 {
			count = int(c)
		}
	}

	result, err := t.provider.Search(ctx, query, count)
	if err != nil {
		return ErrorResult(fmt.Sprintf("search failed: %v", err))
	}

	return &ToolResult{
		ForLLM:  result,
		ForUser: result,
	}
}

type WebFetchTool struct {
	maxChars int
}

func NewWebFetchTool(maxChars int) *WebFetchTool {
	if maxChars <= 0 {
		maxChars = 50000
	}
	return &WebFetchTool{
		maxChars: maxChars,
	}
}

func (t *WebFetchTool) Name() string {
	return "web_fetch"
}

func (t *WebFetchTool) Description() string {
	return "Fetch a specific URL and extract readable content (HTML to text). Only use this when you already have an exact URL (e.g., from web_search results). Do NOT guess URLs — use web_search first to find relevant pages."
}

func (t *WebFetchTool) Parameters() map[string]interface{} {
	return map[string]interface{}{
		"type": "object",
		"properties": map[string]interface{}{
			"url": map[string]interface{}{
				"type":        "string",
				"description": "URL to fetch",
			},
			"maxChars": map[string]interface{}{
				"type":        "integer",
				"description": "Maximum characters to extract",
				"minimum":     100.0,
			},
		},
		"required": []string{"url"},
	}
}

func (t *WebFetchTool) Execute(ctx context.Context, args map[string]interface{}) *ToolResult {
	urlStr, ok := args["url"].(string)
	if !ok {
		return ErrorResult("url is required")
	}

	parsedURL, err := url.Parse(urlStr)
	if err != nil {
		return ErrorResult(fmt.Sprintf("invalid URL: %v", err))
	}

	if parsedURL.Scheme != "http" && parsedURL.Scheme != "https" {
		return ErrorResult("only http/https URLs are allowed")
	}

	if parsedURL.Host == "" {
		return ErrorResult("missing domain in URL")
	}

	maxChars := t.maxChars
	if mc, ok := args["maxChars"].(float64); ok {
		if int(mc) > 100 {
			maxChars = int(mc)
		}
	}

	req, err := http.NewRequestWithContext(ctx, "GET", urlStr, nil)
	if err != nil {
		return ErrorResult(fmt.Sprintf("failed to create request: %v", err))
	}

	req.Header.Set("User-Agent", userAgent)

	client := &http.Client{
		Timeout: 60 * time.Second,
		Transport: &http.Transport{
			MaxIdleConns:        10,
			IdleConnTimeout:     30 * time.Second,
			DisableCompression:  false,
			TLSHandshakeTimeout: 15 * time.Second,
		},
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) >= 5 {
				return fmt.Errorf("stopped after 5 redirects")
			}
			return nil
		},
	}

	resp, err := client.Do(req)
	if err != nil {
		return ErrorResult(fmt.Sprintf("request failed: %v", err))
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return ErrorResult(fmt.Sprintf("failed to read response: %v", err))
	}

	contentType := resp.Header.Get("Content-Type")

	var text, extractor string

	if strings.Contains(contentType, "application/json") {
		var jsonData interface{}
		if err := json.Unmarshal(body, &jsonData); err == nil {
			formatted, _ := json.MarshalIndent(jsonData, "", "  ")
			text = string(formatted)
			extractor = "json"
		} else {
			text = string(body)
			extractor = "raw"
		}
	} else if strings.Contains(contentType, "text/html") || len(body) > 0 &&
		(strings.HasPrefix(string(body), "<!DOCTYPE") || strings.HasPrefix(strings.ToLower(string(body)), "<html")) {
		text = t.extractText(string(body))
		extractor = "text"
	} else {
		text = string(body)
		extractor = "raw"
	}

	truncated := len(text) > maxChars
	if truncated {
		text = text[:maxChars]
	}

	result := map[string]interface{}{
		"url":       urlStr,
		"status":    resp.StatusCode,
		"extractor": extractor,
		"truncated": truncated,
		"length":    len(text),
		"text":      text,
	}

	resultJSON, _ := json.MarshalIndent(result, "", "  ")

	return &ToolResult{
		ForLLM:  fmt.Sprintf("Fetched %d bytes from %s (extractor: %s, truncated: %v)", len(text), urlStr, extractor, truncated),
		ForUser: string(resultJSON),
	}
}

func (t *WebFetchTool) extractText(htmlContent string) string {
	re := regexp.MustCompile(`<script[\s\S]*?</script>`)
	result := re.ReplaceAllLiteralString(htmlContent, "")
	re = regexp.MustCompile(`<style[\s\S]*?</style>`)
	result = re.ReplaceAllLiteralString(result, "")
	re = regexp.MustCompile(`<[^>]+>`)
	result = re.ReplaceAllLiteralString(result, "")

	result = strings.TrimSpace(result)

	re = regexp.MustCompile(`\s+`)
	result = re.ReplaceAllLiteralString(result, " ")

	lines := strings.Split(result, "\n")
	var cleanLines []string
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line != "" {
			cleanLines = append(cleanLines, line)
		}
	}

	return strings.Join(cleanLines, "\n")
}
