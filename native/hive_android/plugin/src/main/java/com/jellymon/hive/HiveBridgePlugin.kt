package com.jellymon.hive

import android.app.Activity
import android.content.Intent
import android.content.Context
import android.util.Log
import android.view.View
import android.view.ViewTreeObserver
import com.hive.AuthV4
import com.hive.DataStore
import com.hive.Configuration
import com.hive.HiveActivity
import com.hive.ResultAPI
import com.hive.Adiz
import com.hive.adiz.AdizError
import com.hive.adiz.AdizListener
import com.hive.adiz.base.AdizRewarded
import com.hive.adiz.common.AdRevenueData
import com.hive.adiz.rewarded.RewardItem
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONObject

/**
 * HIVE SDK/Adiz를 게임 GDScript와 분리하는 Godot Android v2 플러그인.
 * 모든 완료 결과는 Signal로만 돌려주므로 로그인 UI와 광고 보상을 비동기로 처리한다.
 */
class HiveBridgePlugin(godot: Godot) : GodotPlugin(godot) {
    companion object {
        private const val TAG = "HiveBridge"
        private const val SNAPSHOT_KEY = "jellymon_save_v1"
        private const val ADVENTURE_KEY = "jellymon_adventure_v1"
        private val DISCONNECT_COMPLETED = SignalInfo("account_disconnect_completed", java.lang.Boolean::class.java, String::class.java)
        private val RANKING_AUTH = SignalInfo("ranking_auth_ready", java.lang.Integer::class.java,
            java.lang.Boolean::class.java, String::class.java)
        private val SNAPSHOT_LOADED = SignalInfo("game_snapshot_loaded", java.lang.Integer::class.java,
            java.lang.Boolean::class.java, String::class.java, String::class.java)
        private val SNAPSHOT_SAVED = SignalInfo("game_snapshot_saved", java.lang.Integer::class.java,
            java.lang.Boolean::class.java, String::class.java)
        private val RECORD_LOADED = SignalInfo("adventure_record_loaded", java.lang.Integer::class.java,
            java.lang.Boolean::class.java, String::class.java, String::class.java)
        private val RECORD_SAVED = SignalInfo("adventure_record_saved", java.lang.Integer::class.java,
            java.lang.Boolean::class.java, String::class.java)
        private val SETUP_COMPLETED = SignalInfo(
            "hive_setup_completed",
            java.lang.Boolean::class.java,
            String::class.java,
            java.lang.Boolean::class.java
        )
        private val LOGIN_COMPLETED = SignalInfo(
            "hive_login_completed",
            java.lang.Boolean::class.java,
            String::class.java,
            String::class.java,
            String::class.java
        )
        private val AD_STATE = SignalInfo("rewarded_ad_state", String::class.java, String::class.java)
        private val AD_COMPLETED = SignalInfo(
            "rewarded_ad_completed",
            java.lang.Boolean::class.java,
            String::class.java
        )
    }

    private var authenticatedPlayerId = ""
    private var hiveReady = false
    private var autoSignIn = false
    private var disconnecting = false
    private var adizReady = false
    private var rewardedAd: AdizRewarded? = null
    private var pendingAdShow = false
    private var rewardGranted = false
    private var hasStarted = false
    private val windowFocusListener = ViewTreeObserver.OnWindowFocusChangeListener { hasFocus ->
            activity?.let { HiveActivity.onWindowFocusChanged(it, hasFocus) }
    }

    override fun getPluginName() = BuildConfig.GODOT_PLUGIN_NAME

    override fun getPluginSignals(): Set<SignalInfo?> = setOf(
        SETUP_COMPLETED,
        LOGIN_COMPLETED,
        AD_STATE,
        AD_COMPLETED,
        RECORD_LOADED,
        SNAPSHOT_LOADED,
        SNAPSHOT_SAVED,
        RECORD_SAVED,
        RANKING_AUTH,
        DISCONNECT_COMPLETED
    )

    /** Godot Activity의 생명주기를 HIVE에 전달한다. 이 연결이 없으면
     * AuthV4.setup 중 HiveActivity.recentActivity가 초기화되지 않아 종료된다. */
    override fun onMainCreate(activity: Activity?): View? {
        if (activity != null) {
            HiveActivity.onCreate(activity, null)
            activity.window.decorView.viewTreeObserver.addOnWindowFocusChangeListener(windowFocusListener)
        }
        return null
    }

    override fun onMainStart() {
        activity?.let {
            if (hasStarted) HiveActivity.onRestart(it)
            HiveActivity.onStart(it)
        }
        hasStarted = true
    }

    override fun onMainResume() {
        activity?.let { HiveActivity.onResume(it) }
    }

    override fun onMainPause() {
        activity?.let { HiveActivity.onPause(it) }
    }

    override fun onMainStop() {
        activity?.let { HiveActivity.onStop(it) }
    }

    override fun onMainDestroy() {
        rewardedAd?.destroy()
        rewardedAd = null
        activity?.let {
            val observer = it.window.decorView.viewTreeObserver
            if (observer.isAlive) observer.removeOnWindowFocusChangeListener(windowFocusListener)
            HiveActivity.onDestroy(it)
        }
    }

    override fun onMainActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        activity?.let { HiveActivity.onActivityResult(it, requestCode, resultCode, data) }
    }

    override fun onMainRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        activity?.let {
            HiveActivity.onRequestPermissionsResult(it, requestCode, Array(permissions.size) { index -> permissions[index] }, grantResults)
        }
    }

    @UsedByGodot
    fun initialize(testAds: Boolean, sandbox: Boolean) {
        runOnHostThread {
            Log.i(TAG, "initialize zone=${if (sandbox) "SANDBOX" else "REAL"} testAds=$testAds")
            Configuration.zone = if (sandbox) Configuration.ZoneType.SANDBOX else Configuration.ZoneType.REAL
            Adiz.setTestMode(testAds)
            Adiz.setLogEnable(testAds)
            AuthV4.setup(object : AuthV4.AuthV4SetupListener {
                override fun onAuthV4Setup(
                    result: ResultAPI,
                    isAutoSignIn: Boolean,
                    did: String?,
                    providerTypeList: ArrayList<AuthV4.ProviderType>?
                ) {
                    hiveReady = result.isSuccess
                    autoSignIn = isAutoSignIn && activity?.getSharedPreferences("jellymon_auth", Context.MODE_PRIVATE)?.getBoolean("manual_disconnect", false) != true
                    val providers = providerTypeList?.joinToString(",") { it.name } ?: ""
                    val setupMessage = if (hiveReady) {
                        "준비 완료${if (providers.isEmpty()) "" else " · $providers"}"
                    } else {
                        "${result.code}: ${result.message}"
                    }
                    Log.i(TAG, "setup success=$hiveReady autoSignIn=$autoSignIn did=$did providers=$providers result=$result")
                    emitSignal(SETUP_COMPLETED, hiveReady, setupMessage, autoSignIn)
                    // 개발용 테스트 광고는 HIVE Console 인증이 아직 완료되지 않아도
                    // 광고 완료/중도 종료 흐름을 실기기에서 검증할 수 있게 한다.
                    // 상용 빌드(testAds=false)는 약관/인증 초기화 성공 뒤에만 광고를 연다.
                    if (hiveReady || testAds) initializeAdiz()
                }
            })
        }
    }

    @UsedByGodot
    fun login(): Boolean {
        if (!hiveReady) {
            emitSignal(LOGIN_COMPLETED, false, "", "", "HIVE SDK가 아직 준비되지 않았습니다.")
            return false
        }
        runOnHostThread {
            activity?.getSharedPreferences("jellymon_auth", Context.MODE_PRIVATE)?.edit()?.putBoolean("manual_disconnect", false)?.apply()
            Log.i(TAG, "login requested autoSignIn=$autoSignIn")
            val listener = object : AuthV4.AuthV4SignInListener {
                override fun onAuthV4SignIn(result: ResultAPI, playerInfo: AuthV4.PlayerInfo?) {
                    Log.i(TAG, "login completed success=${result.isSuccess} playerId=${playerInfo?.playerId} result=${result.code}")
                    if (result.isSuccess && playerInfo != null) {
                        authenticatedPlayerId = playerInfo.playerId.toString()
                        emitSignal(
                            LOGIN_COMPLETED,
                            true,
                            playerInfo.playerId.toString(),
                            playerInfo.playerName ?: "",
                            ""
                        )
                    } else {
                        authenticatedPlayerId = ""
                        emitSignal(LOGIN_COMPLETED, false, "", "", result.code.toString())
                    }
                }
            }
            if (autoSignIn) {
                AuthV4.signIn(AuthV4.ProviderType.AUTO, listener)
            } else {
                AuthV4.showSignIn(listener)
            }
        }
        return true
    }

    @UsedByGodot
    fun isGuestAccount(): Boolean = AuthV4.getPlayerInfo()?.isGuest() == true

    @UsedByGodot
    fun disconnectAccount(confirmation: String, allowGuestDelete: Boolean) {
        runOnHostThread {
            if (confirmation != "DELETE ACCOUNT" || disconnecting) return@runOnHostThread
            val info = AuthV4.getPlayerInfo()
            if (info == null || authenticatedPlayerId.isEmpty()) {
                emitSignal(DISCONNECT_COMPLETED, false, "Hive 로그인 상태를 확인해 주세요.")
                return@runOnHostThread
            }
            if (info.isGuest() && !allowGuestDelete) {
                emitSignal(DISCONNECT_COMPLETED, false, "Hive 게스트 계정은 일반 로그아웃을 지원하지 않습니다.")
                return@runOnHostThread
            }
            disconnecting = true
            val listener = object : AuthV4.AuthV4SignOutListener {
                override fun onAuthV4SignOut(result: ResultAPI) {
                    disconnecting = false
                    if (result.isSuccess) {
                        authenticatedPlayerId = ""
                        autoSignIn = false
                        activity?.getSharedPreferences("jellymon_auth", Context.MODE_PRIVATE)?.edit()
                            ?.putBoolean("manual_disconnect", true)?.apply()
                    }
                    Log.i(TAG, "account disconnect success=${result.isSuccess} code=${result.code}")
                    emitSignal(DISCONNECT_COMPLETED, result.isSuccess,
                        if (result.isSuccess) "" else "연결 해제 실패: ${result.code}")
                }
            }
            if (info.isGuest()) AuthV4.playerDelete(listener) else AuthV4.signOut(listener)
        }
    }

    @UsedByGodot
    fun prepareRankingAuth(requestId: Int, playerId: String) {
        runOnHostThread {
            if (playerId.isEmpty() || playerId != authenticatedPlayerId) {
                emitSignal(RANKING_AUTH, requestId, false, "")
                return@runOnHostThread
            }
            AuthV4.refreshAccessToken(object : AuthV4.AuthV4RefreshAccessTokenListener {
                override fun onAuthV4RefreshAccessToken(result: ResultAPI, accessToken: String?) {
                    val info = AuthV4.getPlayerInfo()
                    if (!result.isSuccess || info == null || info.playerId.toString() != playerId ||
                        playerId != authenticatedPlayerId || accessToken.isNullOrEmpty()) {
                        emitSignal(RANKING_AUTH, requestId, false, "")
                        return
                    }
                    // 인증 토큰은 메모리로만 전달하며 로그/저장 파일에 남기지 않는다.
                    val credentials = JSONObject().put("player_id", playerId)
                        .put("did", info.did).put("player_token", info.playerToken)
                        .put("access_token", accessToken)
                    emitSignal(RANKING_AUTH, requestId, true, credentials.toString())
                }
            })
        }
    }

    @UsedByGodot
    fun loadAdventureRecord(requestId: Int, playerId: String) {
        runOnHostThread {
            if (!hiveReady || playerId.isEmpty() || playerId != authenticatedPlayerId) {
                emitSignal(RECORD_LOADED, requestId, false, "", "Hive 로그인이 필요합니다.")
                return@runOnHostThread
            }
            // getMyData distinguishes a new account's absent key from a failed read.
            DataStore.getMyData(object : DataStore.DataStoreMyDataListener {
                override fun onDataStoreMyData(result: ResultAPI, myData: Map<String, String>) {
                    val success = result.isSuccess && playerId == authenticatedPlayerId
                    Log.i(TAG, "adventure load success=$success code=${result.code}")
                    emitSignal(RECORD_LOADED, requestId, success,
                        if (success) myData[ADVENTURE_KEY] ?: "" else "",
                        if (success) "" else result.code.toString())
                }
            })
        }
    }

    @UsedByGodot
    fun saveAdventureRecord(requestId: Int, playerId: String, json: String) {
        runOnHostThread {
            if (!hiveReady || playerId.isEmpty() || playerId != authenticatedPlayerId) {
                emitSignal(RECORD_SAVED, requestId, false, "Hive 로그인이 필요합니다.")
                return@runOnHostThread
            }
            DataStore.set(ADVENTURE_KEY, json, object : DataStore.DataStoreSetListener {
                override fun onDataStoreSet(result: ResultAPI) {
                    val success = result.isSuccess && playerId == authenticatedPlayerId
                    Log.i(TAG, "adventure save success=$success code=${result.code}")
                    emitSignal(RECORD_SAVED, requestId, success, if (success) "" else result.code.toString())
                }
            })
        }
    }

    @UsedByGodot
    fun loadGameSnapshot(requestId: Int, playerId: String) {
        runOnHostThread {
            if (!hiveReady || playerId.isEmpty() || playerId != authenticatedPlayerId) {
                emitSignal(SNAPSHOT_LOADED, requestId, false, "", "Hive 로그인이 필요합니다.")
                return@runOnHostThread
            }
            // getMyData distinguishes a new account's absent key from a failed read.
            DataStore.getMyData(object : DataStore.DataStoreMyDataListener {
                override fun onDataStoreMyData(result: ResultAPI, myData: Map<String, String>) {
                    val success = result.isSuccess && playerId == authenticatedPlayerId
                    Log.i(TAG, "snapshot load success=$success code=${result.code}")
                    emitSignal(SNAPSHOT_LOADED, requestId, success,
                        if (success) myData[SNAPSHOT_KEY] ?: "" else "",
                        if (success) "" else result.code.toString())
                }
            })
        }
    }

    @UsedByGodot
    fun saveGameSnapshot(requestId: Int, playerId: String, json: String) {
        runOnHostThread {
            if (!hiveReady || playerId.isEmpty() || playerId != authenticatedPlayerId) {
                emitSignal(SNAPSHOT_SAVED, requestId, false, "Hive 로그인이 필요합니다.")
                return@runOnHostThread
            }
            DataStore.set(SNAPSHOT_KEY, json, object : DataStore.DataStoreSetListener {
                override fun onDataStoreSet(result: ResultAPI) {
                    val success = result.isSuccess && playerId == authenticatedPlayerId
                    Log.i(TAG, "snapshot save success=$success code=${result.code}")
                    emitSignal(SNAPSHOT_SAVED, requestId, success, if (success) "" else result.code.toString())
                }
            })
        }
    }

    @UsedByGodot
    fun isRewardedAdReady(): Boolean = adizReady && rewardedAd?.isLoaded() == true

    @UsedByGodot
    fun showRewardedAd(): Boolean {
        // SDK 조회와 재생은 모두 Android UI 스레드에서 수행한다.
        runOnHostThread {
            if (pendingAdShow) {
                Log.w(TAG, "rewarded duplicate request ignored")
                return@runOnHostThread
            }
            val ad = rewardedAd
            if (!adizReady || ad == null) {
                emitSignal(AD_COMPLETED, false, "광고 SDK가 아직 준비되지 않았습니다.")
                return@runOnHostThread
            }
            if (!ad.isLoaded()) {
                // 늦게 로드된 광고가 다른 화면에서 갑자기 열리지 않도록 재시도를 안내한다.
                emitSignal(AD_COMPLETED, false, "광고를 준비 중입니다. 잠시 후 다시 시도해 주세요.")
                emitSignal(AD_STATE, "loading", "")
                ad.load()
                return@runOnHostThread
            }
            pendingAdShow = true
            rewardGranted = false
            Log.i(TAG, "rewarded show requested loaded=true")
            ad.show()
        }
        return true
    }

    @UsedByGodot
    fun reloadRewardedAd() {
        if (!adizReady) return
        runOnHostThread { rewardedAd?.load() }
    }

    private fun initializeAdiz() {
        val hostActivity = activity
        if (hostActivity == null) {
            emitSignal(AD_STATE, "failed", "Android Activity를 찾을 수 없습니다.")
            return
        }
        Adiz.initialize(hostActivity, object : Adiz.SdkInitializationListener {
            override fun onComplete(error: AdizError, jsonData: JSONObject?) {
                adizReady = error.isSuccess
                Log.i(TAG, "Adiz initialize success=$adizReady code=${error.getCode()} message=${error.getMessage()}")
                if (!adizReady) {
                    emitSignal(AD_STATE, "failed", "${error.getCode()}: ${error.getMessage()}")
                    return
                }
                createRewardedAd()
            }
        })
    }

    private fun createRewardedAd() {
        val listener = object : AdizListener() {
            override fun onLoad() {
                Log.i(TAG, "rewarded onLoad pendingShow=$pendingAdShow")
                emitSignal(AD_STATE, "ready", "")

            }

            override fun onFail(error: AdizError) {
                Log.w(TAG, "rewarded onFail code=${error.getCode()} message=${error.getMessage()}")
                val hadRequest = pendingAdShow
                pendingAdShow = false
                rewardGranted = false
                emitSignal(AD_STATE, "failed", "${error.getCode()}: ${error.getMessage()}")
                if (hadRequest) emitSignal(AD_COMPLETED, false, error.getMessage())
            }

            override fun onShow() {
                Log.i(TAG, "rewarded onShow")
                emitSignal(AD_STATE, "showing", "")
            }

            override fun onClick() = Unit

            override fun onPaidEvent(adRevenueData: AdRevenueData) = Unit

            override fun onRewarded(rewardItem: RewardItem) {
                Log.i(TAG, "rewarded onRewarded")
                if (pendingAdShow) rewardGranted = true
            }

            override fun onClose() {
                if (!pendingAdShow) return
                val granted = rewardGranted
                Log.i(TAG, "rewarded onClose granted=$granted")
                pendingAdShow = false
                rewardGranted = false
                emitSignal(AD_COMPLETED, granted, if (granted) "" else "광고 시청이 완료되지 않았습니다.")
                emitSignal(AD_STATE, "loading", "")
                rewardedAd?.load()
            }
        }
        val hostActivity = activity
        if (hostActivity == null) {
            emitSignal(AD_STATE, "failed", "Android Activity를 찾을 수 없습니다.")
            return
        }
        rewardedAd = AdizRewarded.initialize(hostActivity, listener)
        emitSignal(AD_STATE, "loading", "")
        rewardedAd?.load()
    }
}
