/* global SIP */

import { _t } from "@web/core/l10n/translation";

export class Registerer {
    static EXPIRATION_INTERVAL = 3600;

    state;
    __sipJsRegisterer;

    constructor(voip, sipJsUserAgent) {
        this.voip = voip;
        this.__sipJsRegisterer = new SIP.Registerer(sipJsUserAgent, {
            expires: Registerer.EXPIRATION_INTERVAL,
        });
        this.__sipJsRegisterer.stateChange.addListener((state) =>
            this._onStateChanged(state)
        );
    }

    /**
     * Sends the REGISTER request to the Registrar.
     * BLINDADO: no reenviar REGISTER si ya está registrado
     */
    register() {
        if (this.state === SIP.RegistererState.Registered) {
            return;
        }
        try {
            this.__sipJsRegisterer.register({
                requestDelegate: {
                    onReject: (response) => this._onRegistrationRejected(response),
                },
            });
        } catch (error) {
            console.error("REGISTER error:", error);
        }
    }

    _onRegistrationRejected(response) {
        const errorMessage = _t(
            "Registration rejected: %(statusCode)s %(reasonPhrase)s.",
            {
                statusCode: response.message.statusCode,
                reasonPhrase: response.message.reasonPhrase,
            }
        );
        const help = (() => {
            switch (response.message.statusCode) {
                case 401:
                    return _t(
                        "Authentication failed. Please verify PBX host and credentials."
                    );
                case 503:
                    return _t(
                        "WebSocket transport error. Verify WSS endpoint and TLS."
                    );
                default:
                    return _t(
                        "Please try again later or contact your administrator."
                    );
            }
        })();
        this.voip.triggerError(`${errorMessage}\n\n${help}`);
    }

    _onStateChanged(newState) {
        this.state = newState;
        if (newState === SIP.RegistererState.Registered) {
            this.voip.resolveError();
        }
    }
}
