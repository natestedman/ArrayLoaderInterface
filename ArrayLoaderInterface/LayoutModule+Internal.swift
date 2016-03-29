// ArrayLoaderInterface
// Written in 2016 by Nate Stedman <nate@natestedman.com>
//
// To the extent possible under law, the author(s) have dedicated all copyright and
// related and neighboring rights to this software to the public domain worldwide.
// This software is distributed without any warranty.
//
// You should have received a copy of the CC0 Public Domain Dedication along with
// this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

import LayoutModules
import UIKit

extension LayoutModule
{
    private static func conditionalTableModule(size: CGSize) -> LayoutModule
    {
        return LayoutModule.forMajorAxis(
            horizontal: LayoutModule.table(majorDimension: size.width),
            vertical: LayoutModule.table(majorDimension: size.height)
        )
    }
}

extension LayoutModule
{
    internal static func moduleForSection(section: Section,
                                          activityItemSize: CGSize,
                                          errorItemSize: CGSize,
                                          completedItemSize: CGSize,
                                          customHeaderView: UIView?,
                                          valuesLayoutModule: LayoutModule) -> LayoutModule
    {
        switch section
        {
        case .PreviousPagePull:
            return conditionalTableModule(activityItemSize)

        case .PreviousPageActivity:
            return conditionalTableModule(activityItemSize)

        case .PreviousPageError:
            return conditionalTableModule(errorItemSize)

        case .CustomHeaderView:
            return customHeaderView.map({ view in
                LayoutModule.dynamicTable(calculateMajorDimension: { _, axis, otherDimension in
                    switch axis
                    {
                    case .Horizontal:
                        return view.sizeThatFits(CGSize(width: CGFloat.max, height: otherDimension)).width
                    case .Vertical:
                        return view.sizeThatFits(CGSize(width: otherDimension, height: CGFloat.max)).height
                    }
                })
            }) ?? LayoutModule.table(majorDimension: 0)

        case .Values:
            return valuesLayoutModule

        case .NextPageActivity:
            return conditionalTableModule(activityItemSize)

        case .NextPageError:
            return conditionalTableModule(errorItemSize)

        case .NextPageCompleted:
            return conditionalTableModule(completedItemSize)
        }
    }
}
