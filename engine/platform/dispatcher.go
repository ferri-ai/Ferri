package platform

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/google/uuid"
)

// PostFunc sends a JSON string to Dart via NativePort.
type PostFunc func(jsonStr string)

// Dispatcher handles synchronous blocking for platform tool calls.
// Go goroutines block on a channel until Dart resolves the request.
type Dispatcher struct {
	pending  sync.Map // map[string]chan PlatformResponse
	postFunc PostFunc
	timeout  time.Duration
}

func NewDispatcher(postFunc PostFunc, timeout time.Duration) *Dispatcher {
	if timeout == 0 {
		timeout = 30 * time.Second
	}
	return &Dispatcher{
		postFunc: postFunc,
		timeout:  timeout,
	}
}

// Dispatch sends a tool request to Dart and blocks until the result arrives.
func (d *Dispatcher) Dispatch(ctx context.Context, toolName string, params map[string]interface{}) (string, error) {
	requestID := uuid.New().String()

	// Buffered channel (capacity 1) so Resolve never blocks
	resultCh := make(chan PlatformResponse, 1)
	d.pending.Store(requestID, resultCh)
	defer d.pending.Delete(requestID)

	req := PlatformRequest{
		RequestID: requestID,
		ToolName:  toolName,
		Params:    params,
	}
	reqJSON, err := json.Marshal(req)
	if err != nil {
		return "", fmt.Errorf("failed to marshal platform request: %w", err)
	}

	// Send request to Dart via NativePort
	d.postFunc(string(reqJSON))

	// Block until result, context cancellation, or timeout
	select {
	case resp := <-resultCh:
		if !resp.Success {
			return "", fmt.Errorf("platform tool error: %s", resp.Error)
		}
		return resp.Data, nil
	case <-ctx.Done():
		return "", ctx.Err()
	case <-time.After(d.timeout):
		return "", fmt.Errorf("platform tool %q timed out after %v", toolName, d.timeout)
	}
}

// Resolve unblocks a waiting goroutine with the result from Dart.
func (d *Dispatcher) Resolve(requestID string, responseJSON string) error {
	val, ok := d.pending.Load(requestID)
	if !ok {
		return fmt.Errorf("no pending request for ID %s", requestID)
	}
	ch := val.(chan PlatformResponse)

	var resp PlatformResponse
	if err := json.Unmarshal([]byte(responseJSON), &resp); err != nil {
		resp = PlatformResponse{
			RequestID: requestID,
			Success:   false,
			Error:     fmt.Sprintf("failed to parse response: %s", err),
		}
	}

	ch <- resp
	return nil
}
