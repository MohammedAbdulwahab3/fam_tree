package models

import "time"

// Upload is a file's bytes, held in the database rather than on disk.
//
// The server used to write uploads under ./uploads and serve them statically.
// That works only as long as the container lives: the deployment has no
// persistent disk, so every redeploy — and every wake from the idle sleep a
// free instance goes into after fifteen minutes — replaced the filesystem with
// the image's own, and the file behind a perfectly good URL simply stopped
// existing. Photos vanished while the person record still pointed at them.
//
// The bytes live in a bytea column. That is not how one would store media at
// scale, but a family tree's photographs are a few hundred small images, and a
// row in Postgres survives what a container filesystem does not.
type Upload struct {
	// Name is the generated filename, and the last segment of the URL the
	// client stores. Not the name the uploader's file had.
	Name string `gorm:"primaryKey" json:"name"`

	ContentType string `json:"contentType"`

	// Kind is the coarse category the client switches on: image, video,
	// audio or file.
	Kind string `json:"kind"`

	Data []byte `gorm:"type:bytea" json:"-"`
	Size int64  `json:"size"`

	// UploadedBy is the user id from the token, kept so an upload can be
	// traced back to whoever made it.
	UploadedBy string    `gorm:"index" json:"uploadedBy"`
	CreatedAt  time.Time `json:"createdAt"`
}
