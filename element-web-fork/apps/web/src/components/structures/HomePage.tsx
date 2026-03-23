/*
Copyright 2024 New Vector Ltd.
Copyright 2020 The Matrix.org Foundation C.I.C.

SPDX-License-Identifier: AGPL-3.0-only OR GPL-3.0-only OR LicenseRef-Element-Commercial
Please see LICENSE files in the repository root for full details.
*/

import React, { type JSX } from "react";
import { useContext, useState } from "react";
import { ChatSolidIcon, ExploreIcon, GroupIcon } from "@vector-im/compound-design-tokens/assets/web/icons";

import AutoHideScrollbar from "./AutoHideScrollbar";
import { getHomePageUrl } from "../../utils/pages";
import { _t, _tDom } from "../../languageHandler";
import SdkConfig from "../../SdkConfig";
import dis from "../../dispatcher/dispatcher";
import { Action } from "../../dispatcher/actions";
import BaseAvatar from "../views/avatars/BaseAvatar";
import { OwnProfileStore } from "../../stores/OwnProfileStore";
import AccessibleButton, { type ButtonEvent } from "../views/elements/AccessibleButton";
import { UPDATE_EVENT } from "../../stores/AsyncStore";
import { useEventEmitter } from "../../hooks/useEventEmitter";
import MatrixClientContext, { useMatrixClientContext } from "../../contexts/MatrixClientContext";
import MiniAvatarUploader, { AVATAR_SIZE } from "../views/elements/MiniAvatarUploader";
import PosthogTrackers from "../../PosthogTrackers";
import EmbeddedPage from "./EmbeddedPage";

const onClickSendDm = (ev: ButtonEvent): void => {
    PosthogTrackers.trackInteraction("WebHomeCreateChatButton", ev);
    dis.dispatch({ action: Action.CreateChat });
};

const onClickExplore = (ev: ButtonEvent): void => {
    PosthogTrackers.trackInteraction("WebHomeExploreRoomsButton", ev);
    dis.fire(Action.ViewRoomDirectory);
};

const onClickNewRoom = (ev: ButtonEvent): void => {
    PosthogTrackers.trackInteraction("WebHomeCreateRoomButton", ev);
    dis.dispatch({ action: Action.CreateRoom });
};

const getDayPillar = (): string => {
    const days = ["Sovereign Sunday", "Money Monday", "OPSEC Tuesday", "Wisdom Wednesday", "Business Thursday", "Fitness Friday", "Skills Saturday"];
    return days[new Date().getDay()];
};

interface IProps {
    justRegistered?: boolean;
}

const getOwnProfile = (
    userId: string,
): {
    displayName: string;
    avatarUrl?: string;
} => ({
    displayName: OwnProfileStore.instance.displayName || userId,
    avatarUrl: OwnProfileStore.instance.getHttpAvatarUrl(parseInt(AVATAR_SIZE, 10)) ?? undefined,
});

const UserWelcomeTop: React.FC = () => {
    const cli = useContext(MatrixClientContext);
    const userId = cli.getUserId()!;
    const [ownProfile, setOwnProfile] = useState(getOwnProfile(userId));
    useEventEmitter(OwnProfileStore.instance, UPDATE_EVENT, () => {
        setOwnProfile(getOwnProfile(userId));
    });

    return (
        <div>
            <MiniAvatarUploader
                hasAvatar={!!ownProfile.avatarUrl}
                hasAvatarLabel={_t("onboarding|has_avatar_label")}
                noAvatarLabel={_t("onboarding|no_avatar_label")}
                setAvatarUrl={(url) => cli.setAvatarUrl(url)}
                isUserAvatar
                onClick={(ev) => PosthogTrackers.trackInteraction("WebHomeMiniAvatarUploadButton", ev)}
            >
                <BaseAvatar
                    idName={userId}
                    name={ownProfile.displayName}
                    url={ownProfile.avatarUrl}
                    size={AVATAR_SIZE}
                />
            </MiniAvatarUploader>

            <h1>{_tDom("onboarding|welcome_user", { name: ownProfile.displayName })}</h1>
            <h2>{_tDom("onboarding|welcome_detail")}</h2>
        </div>
    );
};

const HomePage: React.FC<IProps> = ({ justRegistered = false }) => {
    const cli = useMatrixClientContext();
    const config = SdkConfig.get();
    const pageUrl = getHomePageUrl(config, cli);

    if (pageUrl) {
        return <EmbeddedPage className="mx_HomePage" url={pageUrl} scrollbar={true} />;
    }

    let introSection: JSX.Element;
    if (justRegistered || !OwnProfileStore.instance.getHttpAvatarUrl(parseInt(AVATAR_SIZE, 10))) {
        introSection = <UserWelcomeTop />;
    } else {
        const brandingConfig = SdkConfig.getObject("branding");
        const logoUrl = brandingConfig?.get("auth_header_logo_url") ?? "themes/element/img/logos/element-logo.svg";

        introSection = (
            <React.Fragment>
                <img src={logoUrl} alt={config.brand} style={{ height: "80px", filter: "drop-shadow(0 0 20px rgba(123, 104, 238, 0.3))" }} />
                <h1 style={{ color: "#E8E8E8", fontSize: "28px", fontWeight: 700, marginTop: "16px" }}>
                    {config.brand}
                </h1>
                <h2 style={{ color: "#808080", fontSize: "13px", letterSpacing: "2px", textTransform: "uppercase" as const, marginTop: "8px" }}>
                    The underground network for sovereign minds
                </h2>
                <div style={{ marginTop: "24px", padding: "12px 24px", background: "#1A1A2E", borderRadius: "8px", border: "1px solid #2A2A2A" }}>
                    <span style={{ color: "#7B68EE", fontWeight: 600, fontSize: "14px" }}>
                        {getDayPillar()}
                    </span>
                </div>
            </React.Fragment>
        );
    }

    return (
        <AutoHideScrollbar className="mx_HomePage mx_HomePage_default" element="main">
            <div className="mx_HomePage_default_wrapper">
                {introSection}
                <div className="mx_HomePage_default_buttons">
                    <AccessibleButton onClick={onClickSendDm} className="mx_HomePage_button_sendDm">
                        <ChatSolidIcon />
                        {_tDom("onboarding|send_dm")}
                    </AccessibleButton>
                    <AccessibleButton onClick={onClickNewRoom} className="mx_HomePage_button_createGroup">
                        <GroupIcon />
                        {_tDom("onboarding|create_room")}
                    </AccessibleButton>
                </div>
            </div>
        </AutoHideScrollbar>
    );
};

export default HomePage;
