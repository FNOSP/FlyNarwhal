package com.jankinwu.fntv.client.data.model.response

import androidx.compose.runtime.Immutable
import com.fasterxml.jackson.annotation.JsonProperty

@Immutable
data class StreamResponse(
    @param:JsonProperty("file_stream")
    val fileStream: FileInfo,
    @param:JsonProperty("video_stream")
    val videoStream: VideoStream,
    @param:JsonProperty("audio_streams")
    val audioStreams: List<AudioStream>?,
    @param:JsonProperty("qualities")
    val qualities: List<QualityResponse>?,
    @param:JsonProperty("subtitle_streams")
    val subtitleStreams: List<SubtitleStream>?,
    @param:JsonProperty("cloud_storage_info")
    val cloudStorageInfo: CloudStorageInfo?,
)

@Immutable
data class QualityResponse(
    @param:JsonProperty("bitrate")
    val bitrate: Int,

    @param:JsonProperty("resolution")
    val resolution: String,

    @param:JsonProperty("progressive")
    val progressive: Boolean,

    @param:JsonProperty("is_m3u8")
    val isM3u8: Boolean
)

@Immutable
data class CloudStorageInfo(
    /**
     * DAV用户名
     */
    @param:JsonProperty("dav_username")
    val davUsername: String?,

    /**
     * 是否有效
     */
    @param:JsonProperty("valid")
    val valid: Boolean?,

    /**
     * 是否禁用
     */
    @param:JsonProperty("disabled")
    val disabled: Boolean?,

    /**
     * 云存储类型
     */
    @param:JsonProperty("cloud_storage_type")
    val cloudStorageType: Int?,

    /**
     * 云存储昵称
     */
    @param:JsonProperty("cloud_nick_name")
    val cloudNickName: String?,

    /**
     * 文件系统大小
     */
    @param:JsonProperty("fssize")
    val fsSize: Long?,

    /**
     * 文件系统剩余大小
     */
    @param:JsonProperty("frsize")
    val frSize: Long?,

    /**
     * 文件系统已用大小
     */
    @param:JsonProperty("fusize")
    val fuSize: Long?,

    /**
     * 是否是会员
     */
    @param:JsonProperty("is_vip")
    val isVip: Boolean?,

    /**
     * 夸克会员类型
     */
    @param:JsonProperty("quark_vip_type")
    val quarkVipType: String?,

    /**
     * 夸克PC支付链接
     */
    @param:JsonProperty("quark_pc_pay_link")
    val quarkPcPayLink: String?,

    /**
     * 夸克WAP支付链接
     */
    @param:JsonProperty("quark_wap_pay_link")
    val quarkWapPayLink: String?
)