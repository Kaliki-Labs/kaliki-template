package auth_test

import (
	"context"
	"os"
	"testing"

	"github.com/gin-gonic/gin"

	"github.com/example/kitchen-sink-app/backend/internal/auth"
	"github.com/example/kitchen-sink-app/backend/internal/config"
	"github.com/example/kitchen-sink-app/backend/internal/testsupport"
)

var (
	testDB *testsupport.TestDB
	router *gin.Engine
	mailer *recordingMailer
)

// recordingMailer captures sent credentials so tests can read the value that
// would have been emailed. Production never returns credentials in responses,
// so this is the supported way to exercise the verify/reset flows.
type recordingMailer struct {
	verifications map[string]string
	resets        map[string]string
}

func newRecordingMailer() *recordingMailer {
	return &recordingMailer{verifications: map[string]string{}, resets: map[string]string{}}
}

func (m *recordingMailer) SendVerification(_ context.Context, to, credential string) error {
	m.verifications[to] = credential
	return nil
}

func (m *recordingMailer) SendPasswordReset(_ context.Context, to, credential string) error {
	m.resets[to] = credential
	return nil
}

func TestMain(m *testing.M) {
	testDB = testsupport.Connect("test_auth")

	r, api := testsupport.NewRouter()
	mailer = newRecordingMailer()
	auth.New(testDB.Pool, config.TokenConfig{Secret: "test-secret", ExpiryHours: 1}, mailer).Register(api)
	router = r

	os.Exit(m.Run())
}

func setupTest(t *testing.T) {
	t.Helper()
	testDB.Truncate(t)
	mailer.verifications = map[string]string{}
	mailer.resets = map[string]string{}
}
