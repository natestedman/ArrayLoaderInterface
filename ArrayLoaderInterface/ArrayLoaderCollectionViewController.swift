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

// MARK: - Controller

/// A controller that integrates a collection view and an array loader.
///
/// This is not a view controller class - instead, it should be used as part of view controller classes.
public final class ArrayLoaderCollectionViewController
    <ValueDisplay: ValueDisplayType,
     ErrorDisplay: ErrorDisplayType,
     ActivityDisplay,
     PullDisplay: PullDisplayType,
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

    - parameter pullRowHeight:      The row height for the pull-to-refresh cell. The default value of this parameter is
                                    `44`.
    - parameter activityRowHeight:  The row height for activity cells. The default value of this parameter is `44`.
    - parameter errorRowHeight:     The row height for error cells. The default value of this parameter is `44`.
    - parameter completedRowHeight: The row height for the completed footer cell. The default value of this parameter is
                                    `0`.
    - parameter customHeaderView:   An optional custom header view, displayed after activity content for the next page.
    - parameter valuesLayoutModule: The layout module to use for the section displaying the array loader's values.
    */
    public init(
        pullRowHeight: CGFloat = 44,
        activityRowHeight: CGFloat = 44,
        errorRowHeight: CGFloat = 44,
        completedRowHeight: CGFloat = 0,
        customHeaderView: UIView? = nil,
        valuesLayoutModule: LayoutModule)
    {
        self.customHeaderView = customHeaderView

        // create collection view layout
        let layout = LayoutModulesCollectionViewLayout { section in
            switch Section(rawValue: section)!
            {
            case .PreviousPagePull:
                return LayoutModule.table(rowHeight: pullRowHeight)

            case .PreviousPageActivity:
                return LayoutModule.table(rowHeight: activityRowHeight)

            case .PreviousPageError:
                return LayoutModule.table(rowHeight: errorRowHeight)

            case .CustomHeaderView:
                return customHeaderView.map({ view in
                    LayoutModule.dynamicTable(calculateHeight: { _, width in
                        return view.sizeThatFits(CGSize(width: width, height: CGFloat.max)).height
                    })
                }) ?? LayoutModule.table(rowHeight: 0)

            case .Values:
                return valuesLayoutModule

            case .NextPageActivity:
                return LayoutModule.table(rowHeight: activityRowHeight)

            case .NextPageError:
                return LayoutModule.table(rowHeight: errorRowHeight)
                
            case .NextPageCompleted:
                return LayoutModule.table(rowHeight: completedRowHeight)
            }
        }

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
            .flatMap(.Latest, transform: { arrayLoader in
                arrayLoader.state.producer
            })
            .skip(1)
            .observeOn(UIScheduler())
            .startWithNext({ _ in
                if collectionView.window != nil // only reload once the collection view is in a window
                {
                    collectionView.reloadData()
                }
            })
    }

    // MARK: - Collection View

    /// The collection view managed by the controller.
    public let collectionView: UICollectionView

    /// The helper object for this controller.
    private var helper: CollectionViewHelper
        <ValueDisplay, ErrorDisplay, ActivityDisplay, PullDisplay, CompletedDisplay>?

    // MARK: - Array Loader

    /// The array loader being used by the controller.
    public let arrayLoader = MutableProperty(AnyArrayLoader(StaticArrayLoader<ValueDisplay.Value>.empty
        .promoteErrors(ErrorDisplay.Error.self))
    )

    // MARK: - Custom Header View

    /// If provided, this view will be visible below the previous page content.
    let customHeaderView: UIView?

    // MARK: - State

    /// Whether or not the interface should allow loading the previous page - a client might want to limit this by
    /// only allowing the previous page to load if the first page has already loaded.
    public let allowLoadingPreviousPage = MutableProperty(false)

    // MARK: - Callbacks

    /// A callback sent when the user selects a value from the collection view.
    public var didSelectValue: (ValueDisplay.Value -> ())?
}
