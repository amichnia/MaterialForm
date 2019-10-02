import UIKit

internal var isDebuggingViewHierarchy = true

// MARK: - Main Implementation

open class MaterialTextField: UITextField, MaterialField {

    // MARK: - Configuration

    /// Makes intrinsic content size being at least X in height.
    /// Defaults to 50 (recommended 44 + some buffer for the placeholder)
    @IBInspectable open var minimumHeight: CGFloat = 50 { didSet { update() } }

    @IBInspectable open var placeholderScaleMultiplier: CGFloat = 11.0 / 17.0
    @IBInspectable open var placeholderAdjustment: CGFloat = 0.8

    @IBInspectable open var extendLineUnderAccessory: Bool = true { didSet { update() } }

    @IBInspectable open var animationDuration: Float = 0.36
    @IBInspectable open var animationCurve: String? {
        didSet { curve = AnimationCurve(name: animationCurve) ?? curve }
    }
    @IBInspectable open var animationDamping: Float = 1

    @IBInspectable open var radius: CGFloat = 8 { didSet { update(animated: false) } }
    open var insets: UIEdgeInsets = UIEdgeInsets(top: 8, left: 6, bottom: 0, right: 6) {
        didSet { update(animated: false) }
    }

    private var duration: TimeInterval { return TimeInterval(animationDuration) }
    private var curve: AnimationCurve = .easeInOut
    private var damping: CGFloat { return CGFloat(animationDamping) }

    // MARK: - Error handling

    public var isShowingError: Bool { return infoLabel.errorValue != nil }

    public var errorMessage: String? { didSet { update() } }
    @IBInspectable public var infoMessage: String? { didSet { update() } }

    // MARK: - Style

    var style: MaterialTextFieldStyle = DefaultMaterialTextFieldStyle() { didSet { update() } }
    private var defaultStyle: DefaultMaterialTextFieldStyle? { return style as? DefaultMaterialTextFieldStyle }

    // MARK: - Observable properties

    @objc dynamic internal(set) public var event: FieldTriggerEvent = .none
    @objc dynamic internal(set) public var fieldState: FieldControlState = .empty

    // MARK: - Overrides

    open override var intrinsicContentSize: CGSize {
        return super.intrinsicContentSize.constrainedTo(minHeight: minimumHeight)
    }
    open override var placeholder: String? {
        get { return floatingLabel.text }
        set { floatingLabel.text = newValue }
    }
    open override var font: UIFont? {
        didSet { field.font = font }
    }

    open override var inputAccessoryView: UIView? {
        get { return inputAccessory }
        set { inputAccessory = newValue; build() }
    }

    @available(*, unavailable, message: "Not supported")
    open override var leftView: UIView? {
        get { return nil }
        set { /* empty on purpose */ }
    }

    @available(*, unavailable, message: "Not supported")
    open override var rightView: UIView?  {
       get { return nil }
       set { /* empty on purpose */ }
   }

    open override var delegate: UITextFieldDelegate? {
        get { return proxyDelegate }
        set { proxyDelegate = newValue }
    }
    internal weak var proxyDelegate: UITextFieldDelegate? = nil

    // MARK: - Inner structure

    private let mainContainer: UIStackView = {
        let container = UIStackView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.axis = .vertical
        container.alignment = .fill
        container.spacing = 0
        container.isUserInteractionEnabled = true
        return container
    }()
    private let fieldContainer: UIStackView = {
        let container = UIStackView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.axis = .horizontal
        container.alignment = .fill
        container.spacing = 4
        container.isUserInteractionEnabled = true
        return container
    }()

    private var mainContainerTop: NSLayoutConstraint!
    private var mainContainerLeft: NSLayoutConstraint!
    private var mainContainerRight: NSLayoutConstraint!
    private var mainContainerBottom: NSLayoutConstraint!

    private let field: UnderlyingField = UnderlyingField()

    // MARK: - Accessory

    private let accessoryView = UIView()
    private var inputAccessory: UIView?

    // MARK: - Placeholder label

    public var placeholderLabel: UILabel { return floatingLabel }
    private let floatingLabel = UILabel()

    private var topPadding: CGFloat {
        return floatingLabel.font.pointSize * placeholderScaleMultiplier + 4
    }
    private var bottomPadding: CGFloat {
        return infoLabel.bounds.height + lineContainer.bounds.height + mainContainer.spacing * 2
    }

    // MARK: - Underline container

    private var lineContainer = UIView()
    private var lineViewHeight: NSLayoutConstraint?
    private var line = UnderlyingLineView()

    // MARK: - Info view

    public let infoLabel = InfoLabel()
    private let infoContainer: UIStackView = {
        let container = UIStackView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.axis = .horizontal
        container.alignment = .fill
        container.spacing = 4
        container.isUserInteractionEnabled = true
        return container
    }()
    private let infoAccessory = InfoLabel()

    // MARK: - Properties

    var observations: [Any] = []
    private var isBuilt: Bool = false

    // MARK: - Lifecycle

    private lazy var buildOnce: () -> Void = {
        setup()
        build()
        setupObservers()
        return {}
    }()

    open override func layoutSubviews() {
        buildOnce(); super.layoutSubviews()
    }

    // MARK: - Area

    open override func textRect(forBounds bounds: CGRect) -> CGRect {
        let base = super.textRect(forBounds: bounds)
        let textInsets = UIEdgeInsets(
            top: topPadding + insets.top,
            left: insets.left,
            bottom: bottomPadding + insets.bottom,
            right: insets.right
        )
        return base.inset(by: textInsets)
    }

    open override func editingRect(forBounds bounds: CGRect) -> CGRect {
        let base = super.editingRect(forBounds: bounds)
        let textInsets = UIEdgeInsets(
            top: topPadding + insets.top,
            left: insets.left,
            bottom: bottomPadding + insets.bottom,
            right: insets.right
        )
        return base.inset(by: textInsets)
    }

    // MARK: - Setup

    private func setup() {
        placeholder = super.placeholder
        super.placeholder = nil
        super.borderStyle = .none

        if let color = textColor {
            defaultStyle?.defaultColor = color
            defaultStyle?.defaultPlaceholderColor = color
        }

        // TODO: Rest of text field properties
        field.font = font
        field.textColor = .clear
        field.text = placeholder ?? "-"
        field.backgroundColor = .clear
        field.isUserInteractionEnabled = false

        infoLabel.font = .systemFont(ofSize: 11)
        infoLabel.lineBreakMode = .byTruncatingTail
        infoLabel.numberOfLines = 1
    }

    private func setupObservers() {
        observations = [
            observe(\.fieldState) { it, _ in it.update(animated: true) }
        ]
        addTarget(self, action: #selector(updateText), for: .editingChanged)
    }
}

// MARK: - Update

private extension MaterialTextField {

    func update(animated: Bool = true) {
        guard isBuilt else { return }

        super.placeholder = nil
        super.borderStyle = .none

        infoLabel.errorValue = errorMessage
        infoLabel.infoValue = infoMessage

        mainContainerLeft.constant = insets.left
        mainContainerRight.constant = -insets.right

        mainContainerTop.constant = topPadding + insets.top
        mainContainerBottom.constant = -insets.bottom

        setNeedsDisplay()
        setNeedsLayout()

        animateFloatingLabel(animated: animated)
        animateColors(animated: animated)
        infoLabel.update(style: style, animated: animated)
    }

    func updateLineViewHeight() {
        lineViewHeight?.constant = style.maxLineWidth
    }

    func animateFloatingLabel(animated: Bool = true) {
        let up = fieldState == .focused || fieldState == .filled

        guard placeholderScaleMultiplier > 0 else {
            return floatingLabel.isHidden = up
        }

        floatingLabel.textColor = style.textColor(for: self)

        let finalTranform: CGAffineTransform = {
            guard up else {
                return CGAffineTransform.identity
            }

            let left = -floatingLabel.bounds.width / 2
            let top = -floatingLabel.bounds.height / 2
            let bottom = floatingLabel.bounds.height / 2
            let diff = (floatingLabel.bounds.height - floatingLabel.font.pointSize) / 2
            let adjustment = bottom - (topPadding / placeholderScaleMultiplier) - diff

            let moveToZero = CGAffineTransform(translationX: left, y: top)
            let scale = moveToZero.scaledBy(x: placeholderScaleMultiplier, y: placeholderScaleMultiplier)
            return scale.translatedBy(x: -left, y: adjustment)
        }()

        guard animated else {
            return floatingLabel.transform = finalTranform
        }

        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: damping,
            initialSpringVelocity: 0,
            options: curve.asOptions,
            animations: {
                self.floatingLabel.transform = finalTranform
            })
    }

    func animateColors(animated: Bool) {
        let lineWidth = style.lineWidth(for: self)
        let lineColor = style.lineColor(for: self)

        line.animateStateChange { it in
            it.width = lineWidth
            it.color = lineColor
        }

        // TODO: Implement text field and placeholder colors
    }

    @objc func updateText() {
        // Makes text edited observable
        let text = self.text
        self.text = text
    }
}

// MARK: - Build UI Phase

private extension MaterialTextField {

    var isInViewHierarchy: Bool {
        return self.window != nil
    }

    func build() {
        guard isInViewHierarchy else { return }

        buildContainer()
        buildInnerField()
        buildLine()
        buildFloatingLabel()
        buildInfoLabel()
        setupDebug()

        // Setup
        super.delegate = self
        mainContainer.isUserInteractionEnabled = false
        fieldContainer.isUserInteractionEnabled = false
        lineContainer.isUserInteractionEnabled = false
        placeholderLabel.isUserInteractionEnabled = false

        isBuilt = true
        update(animated: false)
    }

    func buildContainer() {
        addSubview(mainContainer.clear())

        mainContainerTop = mainContainer.topAnchor.constraint(equalTo: topAnchor)
        mainContainerLeft = mainContainer.leftAnchor.constraint(equalTo: leftAnchor)
        mainContainerRight = mainContainer.rightAnchor.constraint(equalTo: rightAnchor)
        mainContainerBottom = mainContainer.bottomAnchor.constraint(equalTo: bottomAnchor)

        NSLayoutConstraint.activate([
            mainContainerTop,
            mainContainerLeft,
            mainContainerRight,
            mainContainerBottom
        ])
    }

    func buildInnerField() {
        mainContainer.addArrangedSubview(fieldContainer.clear())

        fieldContainer.addArrangedSubview(field.clear())
        fieldContainer.addArrangedSubview(accessoryView.clear())

        guard let accessory = inputAccessoryView else {
            return accessoryView.isHidden = true
        }

        accessoryView.addSubview(accessory.clear())

        NSLayoutConstraint.activate([
            accessory.topAnchor.constraint(equalTo: accessoryView.topAnchor),
            accessory.leftAnchor.constraint(equalTo: accessoryView.leftAnchor),
            accessory.rightAnchor.constraint(equalTo: accessoryView.rightAnchor),
            accessory.bottomAnchor.constraint(equalTo: accessoryView.bottomAnchor)
        ])
    }

    func buildFloatingLabel() {
        addSubview(floatingLabel.clear())
        bringSubviewToFront(floatingLabel)
        floatingLabel.isUserInteractionEnabled = false

        NSLayoutConstraint.activate([
            floatingLabel.topAnchor.constraint(equalTo: field.topAnchor),
            floatingLabel.leftAnchor.constraint(equalTo: field.leftAnchor),
            floatingLabel.rightAnchor.constraint(equalTo: field.rightAnchor),
            floatingLabel.bottomAnchor.constraint(equalTo: field.bottomAnchor)
        ])
    }

    func buildLine() {
        // Container setup
        lineContainer.clear()
        lineContainer = UIView()
        lineContainer.translatesAutoresizingMaskIntoConstraints = false
        lineContainer.backgroundColor = .clear
        lineContainer.clipsToBounds = false
        mainContainer.addArrangedSubview(lineContainer)

        // Container height
        lineViewHeight = lineContainer.heightAnchor.constraint(equalToConstant: style.maxLineWidth)
        lineViewHeight?.isActive = true

        // Adding actual line
        line = UnderlyingLineView()
        line.translatesAutoresizingMaskIntoConstraints = false
        lineContainer.addSubview(line.clear())

        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: lineContainer.topAnchor),
            line.leftAnchor.constraint(equalTo: leftAnchor),
            line.rightAnchor.constraint(equalTo: rightAnchor)
        ])

        line.buildAsUnderline(for: field)

        // Set initial values
        line.color = style.lineColor(for: self)
        line.width = style.lineWidth(for: self)
        line.underAccessory = extendLineUnderAccessory
    }

    func buildInfoLabel() {
        mainContainer.addArrangedSubview(infoContainer.clear())
        infoContainer.addArrangedSubview(infoLabel)
        infoContainer.addArrangedSubview(infoAccessory)

        infoAccessory.setContentHuggingPriority(.defaultHigh + 1, for: .horizontal)

        infoLabel.field = self
        infoLabel.build()
    }

    func setupDebug() {
        guard isDebuggingViewHierarchy else { return }
        #if DEBUG
        layer.borderWidth = 1
        layer.borderColor = UIColor.red.cgColor
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.green.cgColor
        floatingLabel.layer.borderWidth = 1
        floatingLabel.layer.borderColor = UIColor.blue.cgColor
        #endif
    }
}