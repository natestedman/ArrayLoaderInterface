// ArrayLoaderInterface
// Written in 2016 by Nate Stedman <nate@natestedman.com>
//
// To the extent possible under law, the author(s) have dedicated all copyright and
// related and neighboring rights to this software to the public domain worldwide.
// This software is distributed without any warranty.
//
// You should have received a copy of the CC0 Public Domain Dedication along with
// this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

import ArrayLoader
import LayoutModules
import ReactiveCocoa
import UIKit
import enum Result.NoError

// MARK: - Controller

/// A controller that integrates a collection view and an array loader.
///
/// This is not a view controller class - instead, it should be used as part of view controller classes.
public final class ArrayLoaderCollectionViewController
    <ValueDisplay: ArrayLoaderValueDisplaying,
     ErrorDisplay: ArrayLoaderErrorDisplaying,
     ActivityDisplay,
     PullDisplay: ArrayLoaderPullToRefreshDisplaying,
     CompletedDisplay
     where ValueDisplay: UICollectionViewCell,
           ErrorDisplay: UICollectionViewCell,
           ActivityDisplay: UICollectionViewCell,
           PullDisplay: UICollectionViewCell,
           CompletedDisplay: UICollectionViewCell>
{
    // MARK: - Initialization

    /**
    Initializes an array loader collection view controller.

    - parameter pullItemSize:       The size for the pull-to-refresh cell - only one dimension is used at a time, based
                                    on the current major layout axis. The default value of this parameter is `(44, 44)`.
    - parameter activityItemSize:   The size for activity cells - only one dimension is used at a time, based on the
                                    current major layout axis. The default value of this parameter is `(44, 44)`.
    - parameter errorItemSize:      The row height for error cells - only one dimension is used at a time, based on the
                                    current major layout axis. The default value of this parameter is `(44, 44)`.
    - parameter completedItemSize:  The row height for the completed footer cell - only one dimension is used at a
                                    time, based on the current major layout axis. The default value of this parameter is
                                    `(0, 0)`.
    - parameter customHeaderView:   An optional custom header view, displayed after activity content for the next page.
    - parameter valuesLayoutModule: The layout module to use for the section displaying the array loader's values.
    */
    public init(pullItemSize: CGSize = CGSize(width: 44, height: 44),
                activityItemSize: CGSize = CGSize(width: 44, height: 44),
                errorItemSize: CGSize = CGSize(width: 44, height: 44),
                completedItemSize: CGSize = CGSize.zero,
                customHeaderView: UIView? = nil,
                valuesLayoutModule: LayoutModule)
    {
        self.arrayLoaderState = arrayLoader.value.state.value
        self.customHeaderView = customHeaderView

        // create collection view layout
        self.layout = LayoutModulesCollectionViewLayout(majorAxis: .Vertical, moduleForSection: { section in
            LayoutModule.moduleForSection(
                Section(rawValue: section)!,
                activityItemSize: activityItemSize,
                errorItemSize: errorItemSize,
                completedItemSize: completedItemSize,
                customHeaderView: customHeaderView,
                valuesLayoutModule: valuesLayoutModule
            )
        })

        // create collection view with layout
        let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        self.collectionView = collectionView

        collectionView.registerCellClass(CustomHeaderViewCollectionViewCell.self)
        collectionView.registerCellClass(ValueDisplay)
        collectionView.registerCellClass(ErrorDisplay)
        collectionView.registerCellClass(ActivityDisplay)
        collectionView.registerCellClass(PullDisplay)
        collectionView.registerCellClass(CompletedDisplay)

        // create helper object to implement collection view
        let helper = CollectionViewHelper(parent: self)
        collectionView.dataSource = helper
        collectionView.delegate = helper
        self.helper = helper

        // watch state and reload collection view
        arrayLoader.producer
            .flatMap(.Latest, transform: { $0.events.producer })
            .skip(1)
            .observeOn(UIScheduler())
            .flatMap(.Concat, transform: { [weak self] event in
                self?.updateCollectionViewProducer(for: event) ?? SignalProducer.empty
            })
            .start()

        // automatically load the first page of new array loaders
        arrayLoader.signal.observeNext({ loader in
            if loader.elements.count == 0 && loader.nextPageState.isHasMore
            {
                loader.loadNextPage()
            }
        })
    }

    // MARK: - Collection View

    /// The collection view managed by the controller.
    public let collectionView: UICollectionView

    /// The helper object for this controller.
    private var helper: CollectionViewHelper
        <ValueDisplay, ErrorDisplay, ActivityDisplay, PullDisplay, CompletedDisplay>?

    /// The collection view layout.
    private let layout: LayoutModulesCollectionViewLayout

    /// The current major axis for the collection view layout.
    public var majorAxis: Axis
    {
        get { return layout.majorAxis }
        set { layout.majorAxis = newValue }
    }

    // MARK: - Array Loader

    /// The array loader being used by the controller.
    public let arrayLoader = MutableProperty(
        StaticArrayLoader<ValueDisplay.Value>.empty.promoteErrors(ErrorDisplay.Error.self)
    )

    /// The current array loader display state, which may lag behind the actual state - updates are concatenated by
    /// ReactiveCocoa.
    var arrayLoaderState: LoaderState<ValueDisplay.Value, ErrorDisplay.Error>

    // MARK: - Custom Header View

    /// If provided, this view will be visible below the previous page content.
    let customHeaderView: UIView?

    // MARK: - State

    /// Whether or not the interface should allow loading the previous page - a client might want to limit this by
    /// only allowing the previous page to load if the first page has already loaded.
    public let allowLoadingPreviousPage = MutableProperty(false)

    // MARK: - Callbacks

    /// A callback sent when the user selects a value from the collection view.
    public var didSelectValue: ((cell: UICollectionViewCell?, value: ValueDisplay.Value) -> ())?

    /// A callback sent when the user scrolls the collection view.
    public var didScroll: ((offset: CGPoint) -> ())?
}

extension ArrayLoaderCollectionViewController
{
    private func updateCollectionViewProducer(for event: LoaderEvent<ValueDisplay.Value, ErrorDisplay.Error>)
        -> SignalProducer<(), NoError>
    {
        return SignalProducer { [weak self] observer, disposable in
            // only reload once the collection view is in a window
            guard let strong = self where strong.collectionView.window != nil else { return observer.sendCompleted() }

            // update the local loader state - the collection view data source methods will reference this
            strong.arrayLoaderState = event.state

            switch event
            {
            case .Current:
                strong.collectionView.reloadData()
                observer.sendCompleted()

            case .NextPageLoading:
                disposable += strong.collectionView
                    .updateForPageLoadingEventProducer(sections: [.NextPageActivity, .NextPageError])
                    .start(observer)

            case .PreviousPageLoading:
                disposable += strong.collectionView
                    .updateForPageLoadingEventProducer(sections: [.PreviousPageActivity, .PreviousPageError, .PreviousPagePull])
                    .start(observer)

            case let .NextPageLoaded(state, _, newElements):
                disposable += strong.collectionView
                    .updateForPageLoadedEventProducer(
                        sections: [.NextPageActivity, .NextPageCompleted],
                        indexPaths: (state.elements.count - newElements.count..<state.elements.count).map({ item in
                            NSIndexPath(forItem: item, inSection: Section.Values.rawValue)
                        })
                    )
                    .start(observer)

            case let .PreviousPageLoaded(_, _, newElements):
                disposable += strong.collectionView
                    .updateForPageLoadedEventProducer(
                        sections: [.PreviousPageActivity, .PreviousPagePull],
                        indexPaths: (0..<newElements.count).map({ item in
                            NSIndexPath(forItem: item, inSection: Section.Values.rawValue)
                        })
                    )
                    .start(observer)

            case .NextPageFailed:
                disposable += strong.collectionView
                    .updateForPageLoadingEventProducer(sections: [.NextPageActivity, .NextPageError])
                    .start(observer)

            case .PreviousPageFailed:
                disposable += strong.collectionView
                    .updateForPageLoadingEventProducer(sections: [.PreviousPageActivity, .PreviousPageError])
                    .start(observer)
            }
        }
    }
}

// MARK: - Collection View Updates
extension UICollectionView
{
    private func batchUpdatesProducer(updates: () -> ()) -> SignalProducer<(), NoError>
    {
        return SignalProducer { observer, _ in
            self.performBatchUpdates(updates, completion: { _ in observer.sendCompleted() })
        }
    }

    private func reload(sections sections: [Section])
    {
        let set = NSMutableIndexSet()
        sections.forEach({ set.addIndex($0.rawValue) })
        reloadSections(set)
    }

    private func updateForPageLoadingEventProducer(sections sections: [Section]) -> SignalProducer<(), NoError>
    {
        return batchUpdatesProducer { self.reload(sections: sections) }
    }

    private func updateForPageLoadedEventProducer(sections sections: [Section], indexPaths: [NSIndexPath])
        -> SignalProducer<(), NoError>
    {
        return batchUpdatesProducer {
            self.reload(sections: sections)
            self.insertItemsAtIndexPaths(indexPaths)
        }
    }
}
