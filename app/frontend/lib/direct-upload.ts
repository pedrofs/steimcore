import { DirectUpload } from "@rails/activestorage"

// Uploads a captured photo/video straight to storage (S3 in prod, disk in dev) via
// Active Storage's direct-upload endpoint, bypassing Puma so a phone clip never
// ties up a request worker. Resolves to the blob's `signed_id`, which the server
// attaches with `media.attach(signed_id)` (see Exercise#attach_media!). `onProgress`
// reports 0–100 from the underlying XHR so the queue card can show a progress bar.
const DIRECT_UPLOAD_URL = "/rails/active_storage/direct_uploads"

export function uploadDirect(
  file: File,
  onProgress: (percent: number) => void,
): Promise<string> {
  return new Promise((resolve, reject) => {
    const upload = new DirectUpload(file, DIRECT_UPLOAD_URL, {
      directUploadWillStoreFileWithXHR(xhr) {
        xhr.upload.addEventListener("progress", (event) => {
          if (event.lengthComputable) {
            onProgress(Math.round((event.loaded / event.total) * 100))
          }
        })
      },
    })

    upload.create((error, blob) => {
      if (error || !blob) {
        reject(error ?? new Error("Falha no upload"))
      } else {
        resolve(blob.signed_id)
      }
    })
  })
}
