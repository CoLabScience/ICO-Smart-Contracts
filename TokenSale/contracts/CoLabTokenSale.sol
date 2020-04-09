pragma solidity 0.6.4;

// ----------------------------------------------------------------------------
// CoLab Science Token Crowdsale
//
// Deployed to : <testnet>
// Token      : LAB
// ----------------------------------------------------------------------------

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }
}

interface IERC20 {
    function mint(address _buyer, uint256 _amount) external;
}

contract CoLabTokenSale {
    using SafeMath for uint;

    IERC20 public token;

    address payable public wallet;
    address public owner;
    address public ceo;
    address public updater;
    address public vestedTokenAddr = 0x2a34C464180F7f2910aEe66075b8e7C1F7167caa; // TESTNET
    address public economyAddr = 0xdBA99B92a18930dA39d1e4B52177f84a0C27C8eE; // TESTNET

    uint256 public weiRaised;
    uint256 public phaseStartsAt;
    uint256 public phaseEndsAt;
    uint256 public ethMin;
    uint256 public ethMax;
    uint256 public currentRate;
    uint256 public vestedTokenAmount;
    uint256 public currentPhaseTokenAmount;

    uint8 decimals = 18;

    bool isPaused;

    mapping(address => bool) whitelistedAddrs;

    enum CurrentPhase { Init, None, Private, Main, Fomo }
    CurrentPhase public currentPhase;

    // Referrals
    uint256 public referrerFactor = 1000; // 10 %
    uint256 public parentFactor = 300; // 3 %
    uint256 ppm = 10000;

    struct Ref {
        address buyer; // the purchaser of the tokens
        address referrer; // the person who referred the buyer
        address parent; // the person who referred the buyer's referrer
    }
    Ref[] public refs;
    mapping(address=>bool) hasRef;
    mapping(address=>uint256) buyerToIdx;
    
    event ReferralPaid(address buyer, address referrer, uint256 tokenAmount);
    event AmountRaised(address beneficiary, uint256 amountRaised);
	event TokenPurchased(address indexed purchaser, uint256 tokenAmount, uint256 wieAmount);
    event TokenPurchasedNonETH(address indexed purchaser, uint256 tokenAmount);
	event TokenPhaseStarted(CurrentPhase phase, uint256 startsAt, uint256 endsAt);
	event TokenPhaseEnded(CurrentPhase phase);
    event TokenSaleEnded(uint256 totalSold);
    event RateUpdated(address updater, uint256 rate);

    modifier onlyOwner() {
        require(msg.sender == owner || msg.sender == ceo, "Caller not owner/ceo");
        _;
    }

    modifier onlyUpdater() {
        require(msg.sender == updater, "Caller not updater");
        _;
    }

    modifier whenPhaseActive() {
        require(now >= phaseStartsAt && now <= phaseEndsAt && currentPhase != CurrentPhase.None, "Phase not active");
        _;
    }

    modifier onlyWhitelisted() {
        require(whitelistedAddrs[msg.sender], "Buyer not whitelisted");
        _;
    }

    modifier whenNotPaused() {
        require(!isPaused, "Token sale is paused");
        _;
    }

    constructor(uint256 _rate, address payable _wallet, address _token, address _ceo) public {
        currentPhase = CurrentPhase.Init;
        currentPhaseTokenAmount = 0;
        isPaused = false;
        currentRate = _rate;
        wallet = _wallet;
        token = IERC20(_token);
        owner = msg.sender;
        ceo = _ceo;
        updater = address(0);
        vestedTokenAmount = 50000000 ether; // 50 mil
        ethMin = 0;
        ethMax = 10 ether;
    }

    function buyTokens(address _buyer) public payable whenPhaseActive onlyWhitelisted whenNotPaused {
        require(_buyer != address(0), "Invalid buyer");
        uint256 weiAmount = msg.value;
        require(weiAmount > ethMin && weiAmount <= ethMax, "Invalid ether amount");
        uint256 tokens = weiAmount.mul(currentRate);
        wallet.transfer(msg.value);
        weiRaised = weiRaised.add(weiAmount);
        _doMint(_buyer, tokens);
        // Referrals
        bool isRef = hasRef[_buyer];
        if(isRef) {
            uint256 idx = buyerToIdx[_buyer];
            Ref memory r = refs[idx];
            uint256 rf = weiAmount.mul(referrerFactor).div(ppm);
            uint256 pf = weiAmount.mul(parentFactor).div(ppm);
            if(r.referrer != address(0)) {
                _doMint(r.referrer, rf);
                emit ReferralPaid(_buyer, r.referrer, rf);
            }
            if(r.parent != address(0)) {
                _doMint(r.parent, pf);
                emit ReferralPaid(_buyer, r.parent, pf);
            }
            
        }
        emit TokenPurchased(_buyer, tokens, weiAmount);
    }

    function isWhitelisted(address _address) public view returns(bool) {
        return whitelistedAddrs[_address];
    }

    function initSale() external onlyOwner {
        require(currentPhase == CurrentPhase.Init, "Sale already initialized");
        token.mint(vestedTokenAddr, vestedTokenAmount);
        currentPhase = CurrentPhase.None;
    }

    function startPhase(uint256 _phase) external onlyOwner {
        currentPhase = CurrentPhase(_phase);
        phaseStartsAt = now;
        phaseEndsAt = now + 1 weeks;
        // Rollover previous phase token balance to the current
        currentPhaseTokenAmount = currentPhaseTokenAmount.add(_getPhaseTokenAmount());
    }

    function setRate(uint256 _rate) external onlyOwner onlyUpdater {
        currentRate = _rate;
        emit RateUpdated(msg.sender, _rate);
    }

    function setEthMin(uint256 _ethMin) external onlyOwner {
        ethMin = _ethMin;
    }

    function setEthMax(uint256 _ethMax) external onlyOwner {
        ethMax = _ethMax;
    }

    // For non ETH purchases
    function addTokens(address _buyer, uint256 _tokens, uint256 _weiAmount) external onlyOwner {
        require(_buyer != address(0), "Invalid buyer");
        _doMint(_buyer, _tokens);
        weiRaised = weiRaised.add(_weiAmount);
        emit TokenPurchasedNonETH(_buyer, _tokens);
    }

    function addWhitelistAddr(address _wl) external onlyOwner {
        whitelistedAddrs[_wl] = true;
    }

    function addWhitelistAddrBulk(address[] calldata _wl) external onlyOwner {
        assert(_wl.length <= 200);
        uint256 wlen = _wl.length;
        for(uint8 i = 0; i < wlen; i++) {
            whitelistedAddrs[_wl[i]] = true;
        }
    }

    function changeOwner(address _owner) external onlyOwner {
        owner = _owner;
    }

    function changeUpdater(address _updater) external onlyOwner {
        updater = _updater;
    }

    function setPause(bool _pause) external onlyOwner {
        isPaused = _pause;
    }

    function endTokenSale() external onlyOwner {
        currentPhase = CurrentPhase.None;
        if(currentPhaseTokenAmount > 0) _doMint(economyAddr, currentPhaseTokenAmount);
    }

    function _doMint(address _buyer, uint256 _tokens) internal {
        require(currentPhaseTokenAmount.sub(_tokens) >= 0, "Not enough tokens left in sale");
        currentPhaseTokenAmount = currentPhaseTokenAmount.sub(_tokens);
        if(currentPhaseTokenAmount == 0 && currentPhase != CurrentPhase.None) {
            emit TokenPhaseEnded(currentPhase);
            currentPhase = CurrentPhase.None;
        }
        token.mint(_buyer, _tokens);
    }

    function _getPhaseTokenAmount() internal view returns(uint256) {
        if(currentPhase == CurrentPhase.Private) return 100000000 ether; // 100 mil
        else if(currentPhase == CurrentPhase.Main) return 400000000 ether; // 400 mil
        else if(currentPhase == CurrentPhase.Fomo) return 200000000 ether; // 200 mil
        else return 0;
    }

    receive() external payable {
        buyTokens(msg.sender);
    }

    // Referrals
    function checkRef(address _buyer, uint256 _amount) public view returns(bool, address, uint256, address, uint256) {
        require(_buyer != address(0), "Invalid buyer address");
        require(_amount > 0, "Insufficient amount");
        bool isRef  = hasRef[_buyer];
        if(isRef) {
        uint256 idx = buyerToIdx[_buyer];
        Ref memory r = refs[idx];
        uint256 rf = _amount.mul(referrerFactor);
        uint256 pf = _amount.mul(parentFactor);
        return (isRef, r.referrer, rf.div(ppm), r.parent, pf.div(ppm));
        }
        return (isRef, address(0), 0, address(0), 0);
    }

    function addReferrer(address _referrer, address _buyer) external onlyOwner {
        _addReferrer(_referrer, _buyer);
    }

    function addReferrerBatch(address[] calldata _referrer, address[] calldata _buyer) external onlyOwner {
        require(_referrer.length == _buyer.length, "Mismatching ref and buyer lengths");
        require(_referrer.length <= 200, "Ref length too long");
        uint256 rlen = _referrer.length;
        for(uint8 i = 0; i < rlen; i++) {
        _addReferrer(_referrer[i], _buyer[i]);
        }
    }

    function removeFromRefs(address _buyer) external onlyOwner {
        uint256 idx = buyerToIdx[_buyer];
        require(idx < refs.length, "Out Of Bonds Index");
        delete refs[idx];
    }

    function _addReferrer(address _referrer, address _buyer) internal returns(uint256 rid) {
        Ref memory r = Ref({
            referrer: _referrer,
            buyer: _buyer,
            parent: address(0)
        });
        refs.push(r);
        rid = refs.length.sub(1);
        buyerToIdx[_buyer] = rid;
        hasRef[_buyer] = true;
        // check if referrer has a referrer
        uint256 rIdx = buyerToIdx[_referrer];
        // has parent
        if(rIdx > 0) {
            Ref storage pr = refs[rIdx];
            Ref storage rr = refs[rid];
            rr.parent = pr.referrer;
        }
    }
}