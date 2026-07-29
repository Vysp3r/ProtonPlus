namespace ProtonPlus {
    public enum ReturnCode {
        REQUEST_FAILED,
        INVALID_DATA,
        DOWNLOAD_FAILED,
        FILESYSTEM_ERROR,
        OPERATION_IN_PROGRESS,
        RUNNER_ALREADY_INSTALLED,
        RUNNER_NOT_INSTALLED,
        INVALID_CONFIGURATION,
        UNSUPPORTED_OPERATION,
        RELEASES_LOADED,
        NOTHING_TO_UPDATE,
        RUNNERS_IN_USE,
        RUNNERS_UPDATED,
        RUNNER_UPDATED,
        RUNNER_INSTALLED,
        RUNNER_REMOVED,
        VALID_REQUEST,
        CONNECTION_ISSUE,
        CONNECTION_REFUSED,
        CONNECTION_UNKNOWN,
        API_LIMIT_REACHED,
        INVALID_ACCESS_TOKEN,
        TLS_HANDSHAKE_ERROR,
        UNSUPPORTED_EXTENSION,
        EXTRACTION_FAILED,
        INCOMPATIBLE_VARIANT,
    }

    public string get_return_code_message (ReturnCode code) {
        switch (code) {
        case ReturnCode.REQUEST_FAILED:
            return _ ("The request could not be completed.");
        case ReturnCode.INVALID_DATA:
            return _ ("The required data is invalid or incomplete.");
        case ReturnCode.DOWNLOAD_FAILED:
            return _ ("The download failed.");
        case ReturnCode.FILESYSTEM_ERROR:
            return _ ("A filesystem operation failed.");
        case ReturnCode.OPERATION_IN_PROGRESS:
            return _ ("This compatibility tool is already being processed.");
        case ReturnCode.RUNNER_ALREADY_INSTALLED:
            return _ ("This compatibility tool is already installed.");
        case ReturnCode.RUNNER_NOT_INSTALLED:
            return _ ("This compatibility tool is not installed.");
        case ReturnCode.INVALID_CONFIGURATION:
            return _ ("This compatibility tool is not configured correctly.");
        case ReturnCode.UNSUPPORTED_OPERATION:
            return _ ("This operation is not supported for this compatibility tool.");
        case ReturnCode.CONNECTION_ISSUE:
        case ReturnCode.CONNECTION_REFUSED:
        case ReturnCode.CONNECTION_UNKNOWN:
            return _ ("Unable to reach the API.");
        case ReturnCode.API_LIMIT_REACHED:
            return _ ("API limit reached.");
        case ReturnCode.INVALID_ACCESS_TOKEN:
            return _ ("Invalid access token.");
        case ReturnCode.TLS_HANDSHAKE_ERROR:
            return _ ("A secure connection could not be established.");
        case ReturnCode.UNSUPPORTED_EXTENSION:
            return _ ("This archive format is not supported.");
        case ReturnCode.EXTRACTION_FAILED:
            return _ ("The archive could not be extracted.");
        case ReturnCode.INCOMPATIBLE_VARIANT:
            return _ ("The selected variant is not compatible with this system.");
        default:
            return _ ("The operation could not be completed.");
        }
    }
}
